#!/usr/bin/env python3
"""inject-metadata.py - Inject parent image metadata into Containerfile.

Reads a Containerfile, resolves the metadata chain for each FROM stagex/...
dependency by parsing ancestor Containerfiles directly (no Docker needed),
writes the injected Containerfile to stdout, and writes the merged metadata
to metadata.json for mkoci.sh to embed in OCI images.

Usage: python3 src/inject-metadata.py <stage> <name> <origin>
"""
import json
import os
import sys


def parse_directives(containerfile_path):
    """Parse ENV, SHELL, ENTRYPOINT, WORKDIR from a Containerfile.

    Returns dict with lists of directives in order.
    """
    result = {
        "env": [],
        "shell": None,
        "entrypoint": None,
        "workingdir": None,
    }
    try:
        with open(containerfile_path) as f:
            for line in f:
                s = line.strip()
                if s.startswith("ENV "):
                    rest = s[4:].strip()
                    if "=" in rest:
                        result["env"].append(rest)
                elif s.startswith("SHELL "):
                    result["shell"] = s[6:].strip()
                elif s.startswith("ENTRYPOINT "):
                    result["entrypoint"] = s[11:].strip()
                elif s.startswith("WORKDIR "):
                    result["workingdir"] = s[8:].strip()
    except FileNotFoundError:
        pass
    return result


def get_containerfile_path(dep_name, packages_root="packages"):
    """Get Containerfile path for a dep name like 'pallet-cgo'."""
    parts = dep_name.rsplit("-", 1)
    if len(parts) != 2:
        return None
    stage, pkg_name = parts
    path = os.path.join(packages_root, stage, pkg_name, "Containerfile")
    return path if os.path.isfile(path) else None


def get_from_deps(containerfile_path):
    """Get list of stagex dependencies from FROM lines."""
    deps = []
    try:
        with open(containerfile_path) as f:
            for line in f:
                s = line.strip()
                if s.startswith("FROM stagex/"):
                    parts = s.split()
                    if len(parts) >= 2:
                        deps.append(parts[1].split("/")[1])
                elif s.startswith("FROM --platform=") and "stagex/" in s:
                    parts = s.split()
                    if len(parts) >= 3 and parts[2].startswith("stagex/"):
                        deps.append(parts[2].split("/")[1])
    except FileNotFoundError:
        pass
    return deps


def resolve_chain(dep_name, seen=None):
    """Resolve the full dependency chain from root to leaf.

    Returns ordered list of dep names (bootstrap roots first).
    """
    if seen is None:
        seen = set()
    if dep_name in seen:
        return []
    seen.add(dep_name)

    cf_path = get_containerfile_path(dep_name)
    chain = []
    if cf_path:
        for parent in get_from_deps(cf_path):
            chain.extend(resolve_chain(parent, seen))
    chain.append(dep_name)
    return chain


def merge_directives(chain):
    """Merge directives along the chain. Closer ancestors override."""
    merged = {
        "env": [],
        "shell": None,
        "entrypoint": None,
        "workingdir": None,
    }
    env_keys = set()

    for dep_name in chain:
        cf_path = get_containerfile_path(dep_name)
        if cf_path is None:
            continue
        directives = parse_directives(cf_path)

        # ENV: accumulate, later values override by key
        for entry in directives["env"]:
            if "=" in entry:
                key = entry.split("=")[0]
                if key in env_keys:
                    merged["env"] = [
                        e for e in merged["env"] if e.split("=")[0] != key
                    ]
                else:
                    env_keys.add(key)
                merged["env"].append(entry)

        # SHELL, ENTRYPOINT, WORKDIR: later overrides earlier
        if directives["shell"] is not None:
            merged["shell"] = directives["shell"]
        if directives["entrypoint"] is not None:
            merged["entrypoint"] = directives["entrypoint"]
        if directives["workingdir"] is not None:
            merged["workingdir"] = directives["workingdir"]

    return merged


def format_shell_json(value):
    """Format SHELL value as JSON array for directive."""
    try:
        return json.dumps(json.loads(value))
    except (json.JSONDecodeError, TypeError):
        return value


def write_metadata(stage, name, merged, rootfs_dir="out/rootfs"):
    """Write metadata.json for mkoci.sh to embed in OCI images."""
    meta = {
        "env": merged["env"],
        "shell": json.loads(merged["shell"]) if merged["shell"] else None,
        "entrypoint": json.loads(merged["entrypoint"]) if merged["entrypoint"] else None,
        "cmd": None,
        "workingdir": merged["workingdir"],
    }
    path = os.path.join(rootfs_dir, f"{stage}-{name}", "metadata.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(meta, f, indent=2)
        f.write("\n")


def inject(containerfile_path, stage, name):
    """Read Containerfile, inject metadata after each FROM stagex/... line.

    Returns the injected Containerfile content as a string.
    """
    with open(containerfile_path) as f:
        lines = f.readlines()

    # Track the merged metadata for the current FROM chain
    current_merged = {
        "env": [],
        "shell": None,
        "entrypoint": None,
        "workingdir": None,
    }
    # Collect final merged metadata (last stage) for metadata.json
    final_merged = dict(current_merged)

    output = []
    for line in lines:
        output.append(line)
        stripped = line.strip()

        is_from = False
        dep = None
        if stripped.startswith("FROM stagex/"):
            parts = stripped.split()
            if len(parts) >= 2:
                dep = parts[1].split("/")[1]
                is_from = True
        elif stripped.startswith("FROM --platform=") and "stagex/" in stripped:
            parts = stripped.split()
            if len(parts) >= 3 and parts[2].startswith("stagex/"):
                dep = parts[2].split("/")[1]
                is_from = True

        if not is_from or dep is None:
            continue

        # Resolve chain and merge
        chain = resolve_chain(dep)
        current_merged = merge_directives(chain)
        final_merged = dict(current_merged)

        # Get indentation from the FROM line
        indent = len(line) - len(line.lstrip())
        pad = " " * indent

        # Inject ENV directives
        for env_entry in current_merged["env"]:
            output.append(f"{pad}ENV {env_entry}\n")

        # Inject SHELL directive
        if current_merged["shell"]:
            output.append(f"{pad}SHELL {format_shell_json(current_merged['shell'])}\n")

        # Reset ENTRYPOINT (clear inherited entrypoint for build stages)
        output.append(f"{pad}ENTRYPOINT []\n")

        # Inject WORKDIR (skip if it references unresolved variables)
        if current_merged["workingdir"] and "${" not in current_merged["workingdir"]:
            output.append(f"{pad}WORKDIR {current_merged['workingdir']}\n")

    # Write metadata.json for mkoci.sh
    write_metadata(stage, name, final_merged)

    return "".join(output)


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <stage> <name> <origin>", file=sys.stderr)
        sys.exit(1)

    stage, name, origin = sys.argv[1], sys.argv[2], sys.argv[3]
    containerfile = f"packages/{stage}/{origin}/Containerfile"

    result = inject(containerfile, stage, name)
    sys.stdout.write(result)


if __name__ == "__main__":
    main()
