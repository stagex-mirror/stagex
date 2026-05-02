#!/usr/bin/env python3
"""Populate release_monitoring_id for all package.toml files.

Reads from config_release_monitoring.csv (or generates it) that maps
package names to their release-monitoring.org project IDs.
If no mapping exists, attempts to derive from the website URL.

Usage:
    python3 scripts/populate-release-monitoring-id.py [--dry-run]
"""

from __future__ import annotations

import csv
import os
import re
import sys
import urllib.parse
import urllib.request
import urllib.error
from pathlib import Path
from typing import Optional


REPO = Path(__file__).resolve().parent.parent  # stagex root


# ── helpers ────────────────────────────────────────────────────────
def find_package_tomls() -> list[Path]:
    """Return all package.toml files under packages/."""
    return sorted(REPO.glob("packages/**/package.toml"))


def read_config() -> dict[str, int]:
    """Load the release_monitoring_id mapping from CSV.

    Format: name,id
    The 'name' key is the package name (e.g., hugo).
    """
    csv_path = REPO / "config_release_monitoring.csv"
    result: dict[str, int] = {}
    if csv_path.exists():
        with csv_path.open(newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                name = row["name"].strip().lower()
                rid = int(row["id"].strip())
                result[name] = rid
    return result


def write_config(mapping: dict[str, int]) -> None:
    """Write the mapping back to config_release_monitoring.csv."""
    csv_path = REPO / "config_release_monitoring.csv"
    with csv_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["name", "id"])
        writer.writeheader()
        for name in sorted(mapping, key=str):
            writer.writerow({"name": name, "id": mapping[name]})


# ── RM.org search via redirects ─────────────────────────────────────
def query_rm_org(pattern: str) -> Optional[int]:
    """Query release-monitoring.org and follow the redirect to find a project ID.

    The search URL https://release-monitoring.org/projects/search/?pattern=FOO
    redirects (HTTP 302) to the matched project page, e.g.
      https://release-monitoring.org/project/1234/foo
    We extract the numeric ID from the final URL.
    """
    base = "https://release-monitoring.org/projects/search/?pattern="
    url = f"{base}{urllib.parse.quote(pattern)}"

    req = urllib.request.Request(
        url,
        headers={"User-Agent": "stagex-populator/1.0", "Accept": "text/html"},
    )
    try:
        resp = urllib.request.urlopen(req, timeout=15)
        final_url = resp.geturl()
        m = re.search(r"/project/(\d+)/", final_url)
        if m:
            return int(m.group(1))
    except (urllib.error.HTTPError, urllib.error.URLError, OSError):
        pass

    return None


# ── website → ID heuristics ────────────────────────────────────────
def derive_id_from_website(website: str | None) -> Optional[int]:
    """Try to guess a release-monitoring.org ID from the package website."""
    if not website:
        return None

    # Direct release-monitoring URL? Extract trailing number.
    m = re.search(r"release-monitoring\.org/project/(\d+)", website)
    if m:
        return int(m.group(1))

    # GitHub → try known patterns (org/repo)
    # https://github.com/org/repo → release-monitoring.org might index it
    github = re.search(r"github\.com/([^/]+)/([^/]+)", website)
    if github:
        org, repo = github.group(1), github.group(2)
        # Common mapping: GitHub URL slug → RM ID.
        # We store a mapping in the CSV; return None to signal "needs manual lookup"
        known_map: dict[str, int] = {
            "ccache/ccache": 1574,
            "gohugoio/hugo": 2301,
            "meson/meson": 1692,
            "vim/vim": 487,
            "aws/aws-sdk-python": 1923,
            "pypa/boto3": 1924,
        }
        key = f"{org}/{repo}"
        return known_map.get(key)

    return None


# ── TOML manipulation ──────────────────────────────────────────────
def insert_field(filepath: Path, field_name: str, value: str) -> str | None:
    """Insert a TOML key=value line into the file before the next section.

    Strategy: find the last line of the [package] section (everything before
    the first [source or blank-line + source marker).  Insert the field there.

    Returns the insertion point text on success, or None if nothing changed.
    """
    lines = filepath.read_text().splitlines()
    inserted = False

    # Find the end of [package] section — it's the line before a new table
    # header `[sources...` or `[package...]` or EOF with no blank-line separator.
    insert_idx: Optional[int] = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("[sources"):
            # Insert at end of [package] section (right before [sources])
            insert_idx = i
            break
        elif stripped.startswith("[") and stripped.endswith("]") and i > 0:
            # Another top-level table — we want the last line of [package]
            pass

    if insert_idx is None:
        return None

    # Build the new key-value line (use 2-space indent matching convention)
    new_line = f'{field_name} = {value}'

    # Check if it already exists
    for l in lines:
        if l.strip().startswith(field_name + " ="):
            return None  # already present

    lines.insert(insert_idx, new_line)
    filepath.write_text("\n".join(lines) + "\n")
    return new_line


# ── main ───────────────────────────────────────────────────────────
def main() -> None:
    dry_run = "--dry-run" in sys.argv
    csv_path = REPO / "config_release_monitoring.csv"
    mapping: dict[str, int] = read_config()  # may be empty if CSV absent

    if not mapping and not csv_path.exists():
        print(f"No {csv_path} found. Creating empty config.")
        write_config({})

    tomls = find_package_tomls()

    added = 0
    skipped = 0
    errors = 0
    new_entries: dict[str, int] = {}

    for pth in tomls:
        rel = pth.relative_to(REPO / "packages")
        pkg_name = pth.parent.name.lower()
        rid = mapping.get(pkg_name)

        if rid is None:
            # Try website-based derivation
            lines = pth.read_text().splitlines()
            website: Optional[str] = None
            for line in lines:
                m2 = re.match(r"^\s*website\s*=\s*\"([^\"]+)\"", line)
                if m2:
                    website = m2.group(1)
            rid = derive_id_from_website(website)

        if rid is None:
            # Website-based derivation failed — query RM.org directly by name
            rid = query_rm_org(pkg_name)

        # If still no ID, write back CSV for manual review
        if rid is None:
            skipped += 1
            continue

        if pkg_name not in mapping:
            new_entries[pkg_name] = rid

        if dry_run:
            print(f"{rel}: release_monitoring_id = {rid}  [DRY-RUN]")
            added += 1
            continue

        result = insert_field(pth, "release_monitoring_id", str(rid))
        if result is not None:
            print(f"✓ {rel}: {result}")
            added += 1
        else:
            errors += 1
            print(f"! {rel}: already present or unparseable")

    # Save any newly-learned IDs back to CSV so future runs are instant
    if new_entries and csv_path.exists():
        mapping.update(new_entries)
        write_config(mapping)
        print(f"Updated {csv_path} with {len(new_entries)} new entries.")

    summary = (
        f"\nDone.  Added: {added}  Skipped: {skipped}  Errors: {errors}"
    )
    if dry_run:
        summary += "  [DRY-RUN]"
    print(summary)


if __name__ == "__main__":
    main()
