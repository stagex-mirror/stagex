#!/usr/bin/env python3
"""Lint stagex Containerfiles for stage-naming convention compliance.

Rules per packages/<cat>/<name>/Containerfile:

1. Every `FROM ... AS <stage>` line whose stage starts with `package` must
   match exactly one of:
       package
       package_runtime
       package-<sub>
       package-<sub>_runtime
   `<sub>` must appear in the corresponding package.toml's `subpackages` list.
   The underscore separator on `_runtime` keeps the closure suffix disjoint
   from subpackage names (which use hyphens).

2. If `subpackages` is declared in package.toml: there must be one
   `AS package-<sub>` stage per declared subpackage, and there must NOT be a
   bare `AS package` stage.

3. If `subpackages` is NOT declared: the file must either contain a bare
   `AS package` stage, or have no `package*` stages at all (rebase pattern,
   typical of `packages/pallet/`).

4. No trailing whitespace on `AS <stage>` lines.

5. Each `AS <stage>` name must be unique within the file.

Usage:
    src/lint-containerfiles.py [path...]   # lint given Containerfiles
    src/lint-containerfiles.py             # lint all packages/*/*/Containerfile

Exits 1 if any violations are found.
"""

import os
import re
import sys
from glob import glob

try:
    import tomllib  # py311+
except ModuleNotFoundError:
    import tomli as tomllib  # type: ignore

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Capture the raw stage name including any trailing whitespace so we can flag it.
FROM_AS_RE = re.compile(r"^FROM\s+\S+(?:\s+--platform=\S+)?\s+AS\s+(.+?)\s*$")


def classify_package_stage(stage: str):
    """Return (sub, is_runtime) for a 'package*' stage, or None if not package family.

    `sub` is None for the bare package family ('package', 'package_runtime').
    The underscore separator on '_runtime' keeps the closure suffix disjoint
    from subpackage names (which use hyphens), so there is no ambiguity.
    """
    if stage == "package":
        return (None, False)
    if stage == "package_runtime":
        return (None, True)
    if not stage.startswith("package-"):
        return None
    rest = stage[len("package-"):]
    if rest.endswith("_runtime"):
        return (rest[:-len("_runtime")], True)
    return (rest, False)


def parse_subpackages(toml_path: str) -> list[str]:
    if not os.path.isfile(toml_path):
        return []
    with open(toml_path, "rb") as f:
        data = tomllib.load(f)
    pkg = data.get("package", {}) or {}
    subs = pkg.get("subpackages", [])
    return list(subs) if isinstance(subs, list) else []


def lint_file(path: str) -> list[str]:
    """Return a list of error strings; empty if the file is clean."""
    errors: list[str] = []
    pkg_dir = os.path.dirname(path)
    subpackages = parse_subpackages(os.path.join(pkg_dir, "package.toml"))
    sub_set = set(subpackages)

    stages_seen: dict[str, int] = {}
    package_stages: set[str] = set()
    package_sub_stages: set[str] = set()
    has_bare_package = False

    with open(path) as f:
        for lineno, raw in enumerate(f, 1):
            line = raw.rstrip("\n")
            if not line.startswith("FROM"):
                continue
            m = FROM_AS_RE.match(line)
            if not m:
                continue
            stage_raw = m.group(1)
            stage = stage_raw.rstrip()
            if stage != stage_raw:
                errors.append(f"{path}:{lineno}: trailing whitespace on stage name 'AS {stage_raw}'")

            if stage in stages_seen:
                errors.append(
                    f"{path}:{lineno}: duplicate stage name '{stage}' "
                    f"(first defined on line {stages_seen[stage]})"
                )
            else:
                stages_seen[stage] = lineno

            if not stage.startswith("package"):
                continue

            parsed = classify_package_stage(stage)
            if parsed is None:
                errors.append(
                    f"{path}:{lineno}: invalid package stage name '{stage}' "
                    f"(expected: package, package_runtime, package-<sub>, or package-<sub>_runtime)"
                )
                continue

            sub, is_runtime = parsed
            if sub is None:
                has_bare_package = True
                package_stages.add("package_runtime" if is_runtime else "package")
            else:
                if sub == "":
                    errors.append(
                        f"{path}:{lineno}: invalid package stage name '{stage}' (empty subpackage)"
                    )
                    continue
                if sub not in sub_set:
                    errors.append(
                        f"{path}:{lineno}: stage '{stage}' references subpackage '{sub}' "
                        f"not declared in package.toml's subpackages list"
                    )
                package_sub_stages.add(sub)

    has_any_package_stage = bool(package_stages or package_sub_stages)

    if sub_set:
        if has_bare_package:
            errors.append(
                f"{path}: bare 'AS package' stage is not allowed when subpackages "
                f"are declared (declared: {sorted(sub_set)})"
            )
        missing = sub_set - package_sub_stages
        if missing:
            errors.append(
                f"{path}: missing 'AS package-<sub>' stage(s) for declared "
                f"subpackage(s): {sorted(missing)}"
            )
    else:
        if has_any_package_stage and not has_bare_package:
            errors.append(
                f"{path}: package has no declared subpackages but Containerfile "
                f"is missing a bare 'AS package' stage"
            )

    return errors


def collect_default_paths() -> list[str]:
    return sorted(glob(os.path.join(REPO_ROOT, "packages", "*", "*", "Containerfile")))


def main(argv: list[str]) -> int:
    paths = argv[1:] if len(argv) > 1 else collect_default_paths()
    paths = [p for p in paths if os.path.basename(p) == "Containerfile" and os.path.isfile(p)]
    if not paths:
        print("lint-containerfiles: no Containerfiles to check", file=sys.stderr)
        return 0

    all_errors: list[str] = []
    for path in paths:
        all_errors.extend(lint_file(path))

    if all_errors:
        for err in all_errors:
            print(err)
        print(f"\nlint-containerfiles: {len(all_errors)} violation(s) in {len(paths)} file(s)",
              file=sys.stderr)
        return 1

    print(f"lint-containerfiles: OK ({len(paths)} file(s) checked)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
