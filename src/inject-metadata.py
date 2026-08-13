#!/usr/bin/env python3
"""inject-metadata.py - Inject parent image metadata into Containerfile.

Reads a Containerfile, resolves the metadata chain for each FROM stagex/...
dependency, and writes the injected Containerfile to stdout.

Usage: python3 src/inject-metadata.py <stage> <name> <origin>

The metadata chain is resolved recursively: for pallet-cgo it walks
pallet-cgo → pallet-go → core-profile → bootstrap-stage3, merging
metadata at each step (closer ancestors override earlier ones).
"""
import json
import os
import sys


def load_metadata(dep_name, rootfs_dir="out/rootfs"):
    """Load metadata.json for a dependency, or None if not built yet."""
    path = os.path.join(rootfs_dir, dep_name, "metadata.json")
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def parse_containerfile_deps(containerfile_path):
    """Parse FROM/COPY --from lines to get stagex dependencies in order."""
    deps = []
    from_stages = []
    try:
        with open(containerfile_path) as f:
            for line in f:
                stripped = line.strip()
                if stripped.startswith("FROM stagex/"):
                    dep = stripped.split()[1].split("/")[1].strip()
                    deps.append(dep)
                    stage = ""
                    parts = stripped.split()
                    for i, p in enumerate(parts):
                        if p == "AS" and i + 1 < len(parts):
                            stage = parts[i + 1]
                            break
                    from_stages.append(stage)
                elif stripped.startswith("FROM --platform=") and "stagex/" in stripped:
                    dep = stripped.split()[-1].split("/")[1].strip()
                    if "stagex/" in stripped.split()[-1]:
                        deps.append(dep)
                        from_stages.append("")
    except FileNotFoundError:
        pass
    return list(zip(from_stages, deps))


def resolve_chain(dep_name, packages_root="packages"):
    """Resolve the full metadata chain for a dependency.

    Returns ordered list of dep names from root (bootstrap) to leaf.
    """
    chain = []
    seen = set()

    def walk(name):
        if name in seen:
            return
        seen.add(name)
        # Find stage/name from dep name like "pallet-cgo"
        parts = name.rsplit("-", 1)
        if len(parts) != 2:
            return
        stage, pkg_name = parts
        cf_path = os.path.join(packages_root, stage, pkg_name, "Containerfile")
        from_deps = parse_containerfile_deps(cf_path)
        for _, parent in from_deps:
            walk(parent)
        chain.append(name)

    walk(dep_name)
    return chain


def merge_metadata(chain, rootfs_dir="out/rootfs"):
    """Merge metadata along the chain. Later entries override earlier ones."""
    merged = {
        "env": [],
        "shell": None,
        "entrypoint": None,
        "cmd": None,
        "workingdir": None,
    }
    env_seen = set()

    for dep_name in chain:
        meta = load_metadata(dep_name, rootfs_dir)
        if meta is None:
            continue
        # ENV: accumulate, later values override by key
        if meta.get("env"):
            for entry in meta["env"]:
                if "=" in entry:
                    key = entry.split("=")[0]
                    if key in env_seen:
                        # Replace existing value for this key
                        merged["env"] = [
                            e for e in merged["env"] if e.split("=")[0] != key
                        ]
                    else:
                        env_seen.add(key)
                    merged["env"].append(entry)
        # SHELL, ENTRYPOINT, CMD, WORKDIR: later overrides
        if meta.get("shell") is not None:
            merged["shell"] = meta["shell"]
        if meta.get("entrypoint") is not None:
            merged["entrypoint"] = meta["entrypoint"]
        if meta.get("cmd") is not None:
            merged["cmd"] = meta["cmd"]
        if meta.get("workingdir") is not None:
            merged["workingdir"] = meta["workingdir"]

    return merged


def format_shell_json(values):
    """Format a list as JSON array for SHELL/ENTRYPOINT directive."""
    return json.dumps(values)


def inject(containerfile_path, stage, name, origin):
    """Read Containerfile, inject metadata after each FROM stagex/... line."""
    deps = parse_containerfile_deps(containerfile_path)

    with open(containerfile_path) as f:
        lines = f.readlines()

    output = []
    for i, line in enumerate(lines):
        output.append(line)
        stripped = line.strip()

        if not (stripped.startswith("FROM stagex/") or
                (stripped.startswith("FROM --platform=") and "stagex/" in stripped)):
            continue

        # Extract dep name
        dep = None
        if stripped.startswith("FROM stagex/"):
            dep = stripped.split()[1].split("/")[1].strip()
        elif "stagex/" in stripped.split()[-1]:
            dep = stripped.split()[-1].split("/")[1].strip()

        if dep is None:
            continue

        # Resolve chain and merge metadata
        chain = resolve_chain(dep)
        merged = merge_metadata(chain)

        if not merged["env"] and merged["shell"] is None:
            continue

        # Get indentation from the FROM line
        indent = len(line) - len(line.lstrip())
        pad = " " * indent

        # Inject ENV directives
        for env_entry in merged["env"]:
            output.append(f"{pad}ENV {env_entry}\n")

        # Inject SHELL directive
        if merged["shell"]:
            output.append(f"{pad}SHELL {format_shell_json(merged['shell'])}\n")

        # Reset ENTRYPOINT (clear inherited entrypoint for build stages)
        output.append(f"{pad}ENTRYPOINT []\n")

        # Inject WORKDIR
        if merged["workingdir"]:
            output.append(f"{pad}WORKDIR {merged['workingdir']}\n")

    return "".join(output)


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <stage> <name> <origin>", file=sys.stderr)
        sys.exit(1)

    stage, name, origin = sys.argv[1], sys.argv[2], sys.argv[3]
    containerfile = f"packages/{stage}/{origin}/Containerfile"

    result = inject(containerfile, stage, name, origin)
    sys.stdout.write(result)


if __name__ == "__main__":
    main()
