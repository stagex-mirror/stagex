#!/usr/bin/env python3
"""inject-metadata.py - Inject parent image metadata into Containerfile.

When a dependency is supplied as a local rootfs build-context (instead of a
docker image), the image-config metadata Docker would normally carry (ENV,
SHELL, ENTRYPOINT, WORKDIR) is lost. This tool restores it.

For each `FROM stagex/...` dependency it resolves the environment that the
dependency's *image* would carry and injects those directives after the FROM
line. The image environment is computed the same way Docker computes it:

  image_env(dep) = merge( image_env(base), target_stage_own_directives )

where `base` is the target stage's FROM base (a stagex image, a local stage,
or scratch) and `target_stage` is the stage that becomes the image (the
`package` / `package-<sub>` stage, or the final stage when there is none).

Only the target stage's own directives are considered - not build-stage
directives - so build-only variables (e.g. bootstrap-stage1's `DISK=sda1`)
do not leak into derived images.

The merged metadata for the built package's final base is written to
metadata.json for mkoci.sh to embed in the OCI image config.

Usage: python3 src/inject-metadata.py <stage> <name> <origin>
"""
import json
import os
import re
import sys

from common import CommonUtils


# Stage prefixes that appear in packages/<stage>/<name>/
STAGE_PREFIXES = ["bootstrap", "core", "user", "box", "pallet", "service", "distro"]

_FROM_RE = re.compile(
    r"^FROM\s+(?:--platform=[^\s]+\s+)?([^\s]+)(?:\s+AS\s+(\S+))?\s*$"
)


def _parse_containerfile_stages(containerfile_path):
    """Parse a Containerfile into an ordered list of stage descriptors.

    Returns (stages, lines) where stages is a list of dicts
    {"name", "base", "start", "end"} (start = the FROM line index, end = index
    one past the last line of the block). Stages without an `AS` name get
    name=None.
    """
    try:
        with open(containerfile_path) as f:
            lines = f.readlines()
    except FileNotFoundError:
        return [], []

    stages = []
    for i, line in enumerate(lines):
        m = _FROM_RE.match(line.strip())
        if not m:
            continue
        base = m.group(1)
        name = m.group(2)
        end = len(lines)
        for j in range(i + 1, len(lines)):
            if _FROM_RE.match(lines[j].strip()):
                end = j
                break
        stages.append({"name": name, "base": base, "start": i, "end": end})
    return stages, lines


class PackageIndex(object):
    """Index of packages and subpackages under packages/."""

    def __init__(self, root="packages"):
        self.root = root
        self._main = None      # (stage,name) -> package dir
        self._sub = None       # full subpackage name -> (stage, origin_name, sub_name)

    def _ensure(self):
        if self._main is not None:
            return
        self._main = {}
        self._sub = {}
        if not os.path.isdir(self.root):
            return
        for stage in os.listdir(self.root):
            sdir = os.path.join(self.root, stage)
            if not os.path.isdir(sdir):
                continue
            for name in os.listdir(sdir):
                toml_path = os.path.join(sdir, name, "package.toml")
                cf_path = os.path.join(sdir, name, "Containerfile")
                if not os.path.isfile(toml_path) or not os.path.isfile(cf_path):
                    continue
                self._main[(stage, name)] = os.path.join(sdir, name)
                try:
                    data = CommonUtils.toml_read(toml_path)
                except Exception:
                    continue
                for sub in data.get("package", {}).get("subpackages", []):
                    self._sub[f"{stage}-{sub}"] = (stage, name, sub)

    def resolve(self, dep_name):
        """Resolve a dep name to (containerfile_path, target_stage_name).

        Returns None if the dependency cannot be resolved to a local package.
        """
        self._ensure()

        # Subpackage reference (e.g. user-linux-server -> user/linux sub)
        if dep_name in self._sub:
            stage, origin_name, sub_name = self._sub[dep_name]
            cf = os.path.join(self.root, stage, origin_name, "Containerfile")
            return cf, f"package-{sub_name}"

        # Main package reference
        for stage in STAGE_PREFIXES:
            if dep_name.startswith(stage + "-"):
                name = dep_name[len(stage) + 1:]
                key = (stage, name)
                if key in self._main:
                    pkgdir = self._main[key]
                    return os.path.join(pkgdir, "Containerfile"), self._target_stage(
                        pkgdir
                    )

        # Fallback: split on last hyphen (handles unusual stage names)
        parts = dep_name.rsplit("-", 1)
        if len(parts) == 2:
            stage, name = parts
            pkgdir = os.path.join(self.root, stage, name)
            cf = os.path.join(pkgdir, "Containerfile")
            if os.path.isfile(cf):
                return cf, self._target_stage(pkgdir)
        return None

    @staticmethod
    def _has_package_stage(containerfile_path):
        try:
            with open(containerfile_path) as f:
                for line in f:
                    s = line.strip()
                    if s.endswith(" AS package") and " AS package-" not in s:
                        return True
        except FileNotFoundError:
            pass
        return False

    def _target_stage(self, pkgdir):
        """Return the name of the stage that becomes the image for pkgdir.

        Mirrors the --target selection in targets.get_build_args: a main
        package with subpackages and a `package` stage targets `package`;
        otherwise the final (last) stage is the image.
        """
        cf = os.path.join(pkgdir, "Containerfile")
        toml_path = os.path.join(pkgdir, "package.toml")
        has_pkg_stage = self._has_package_stage(cf)
        has_subpackages = False
        try:
            data = CommonUtils.toml_read(toml_path)
            has_subpackages = bool(data.get("package", {}).get("subpackages", []))
        except Exception:
            pass
        if has_subpackages and has_pkg_stage:
            return "package"
        stages, _ = _parse_containerfile_stages(cf)
        if not stages:
            return None
        return stages[-1]["name"]


def _directives_in_block(lines, start, end):
    """Parse ENV/SHELL/ENTRYPOINT/WORKDIR directives within a stage block."""
    result = {"env": [], "shell": None, "entrypoint": None, "workingdir": None}
    for i in range(start, end):
        s = lines[i].strip()
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
    return result


def _merge_directives(chain_directives):
    """Merge an ordered list of directive dicts (base -> leaf).

    Later entries override earlier ones. ENV accumulates with later values
    winning per key; SHELL/ENTRYPOINT/WORKDIR are last-wins.
    """
    merged = {"env": [], "shell": None, "entrypoint": None, "workingdir": None}
    env_keys = set()
    for d in chain_directives:
        for entry in d["env"]:
            key = entry.split("=")[0]
            if key in env_keys:
                merged["env"] = [
                    e for e in merged["env"] if e.split("=")[0] != key
                ]
            else:
                env_keys.add(key)
            merged["env"].append(entry)
        if d["shell"] is not None:
            merged["shell"] = d["shell"]
        if d["entrypoint"] is not None:
            merged["entrypoint"] = d["entrypoint"]
        if d["workingdir"] is not None:
            merged["workingdir"] = d["workingdir"]
    return merged


class MetadataResolver(object):
    """Resolves image metadata for stagex dependencies."""

    def __init__(self, root="packages"):
        self.index = PackageIndex(root)
        self._stage_cache = {}
        self._env_cache = {}

    def _stages(self, cf_path):
        if cf_path not in self._stage_cache:
            self._stage_cache[cf_path] = _parse_containerfile_stages(cf_path)
        return self._stage_cache[cf_path]

    def _stage_by_name(self, cf_path, name):
        stages, _ = self._stages(cf_path)
        for st in stages:
            if st["name"] == name:
                return st
        if name is None and stages:
            return stages[-1]
        return None

    def image_directives(self, dep_name, seen=None):
        """Return merged image directives for a stagex dependency.

        Follows the target stage's FROM base chain (base -> leaf) and merges
        only each stage's own directives.
        """
        if seen is None:
            seen = set()
        if dep_name in self._env_cache:
            return self._env_cache[dep_name]
        if dep_name in seen:
            return {"env": [], "shell": None, "entrypoint": None, "workingdir": None}
        seen.add(dep_name)

        resolved = self.index.resolve(dep_name)
        if resolved is None:
            empty = {"env": [], "shell": None, "entrypoint": None, "workingdir": None}
            return empty
        cf_path, target_name = resolved
        stage = self._stage_by_name(cf_path, target_name)
        if stage is None:
            empty = {"env": [], "shell": None, "entrypoint": None, "workingdir": None}
            self._env_cache[dep_name] = empty
            return empty

        chain = []
        base = stage["base"]
        if base.startswith("stagex/"):
            base_dep = base.split("/", 1)[1]
            chain.append(self.image_directives(base_dep, seen))
        elif base != "scratch":
            chain.append(self._local_stage_directives(cf_path, base, seen))

        chain.append(_directives_in_block(*self._block_range(cf_path, stage)))
        merged = _merge_directives(chain)
        self._env_cache[dep_name] = merged
        return merged

    def _block_range(self, cf_path, stage):
        _, lines = self._stages(cf_path)
        return lines, stage["start"], stage["end"]

    def _local_stage_directives(self, cf_path, name, seen):
        """Resolve directives for a local (non-stagex) stage base within a file."""
        stages, lines = self._stages(cf_path)
        for st in stages:
            if st["name"] != name:
                continue
            chain = []
            base = st["base"]
            if base.startswith("stagex/"):
                chain.append(self.image_directives(base.split("/", 1)[1], seen))
            elif base != "scratch":
                chain.append(self._local_stage_directives(cf_path, base, seen))
            chain.append(_directives_in_block(lines, st["start"], st["end"]))
            return _merge_directives(chain)
        return {"env": [], "shell": None, "entrypoint": None, "workingdir": None}


def format_shell_json(value):
    """Format SHELL value as JSON array for directive."""
    try:
        return json.dumps(json.loads(value))
    except (json.JSONDecodeError, TypeError):
        return value


def write_metadata(stage, name, merged, rootfs_dir="out/rootfs"):
    """Write metadata.json for mkoci.sh to embed in OCI images.

    Only writes if content changed, to avoid invalidating make cache.
    """
    meta = {
        "env": merged["env"],
        "shell": json.loads(merged["shell"]) if merged["shell"] else None,
        "entrypoint": json.loads(merged["entrypoint"])
        if merged["entrypoint"]
        else None,
        "cmd": None,
        "workingdir": merged["workingdir"],
    }
    new_content = json.dumps(meta, indent=2) + "\n"
    path = os.path.join(rootfs_dir, f"{stage}-{name}", "metadata.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Always write so the mtime is refreshed. metadata.json is the make
    # sentinel for this recipe; if we skipped the write when content was
    # unchanged, the mtime would stay older than src/inject-metadata.py and
    # make would re-run the recipe on every invocation.
    with open(path, "w") as f:
        f.write(new_content)


def inject(containerfile_path, stage, name, resolver):
    """Read Containerfile, inject image metadata after each FROM stagex/ line."""
    with open(containerfile_path) as f:
        lines = f.readlines()

    output = []
    final_merged = {"env": [], "shell": None, "entrypoint": None, "workingdir": None}

    for i, line in enumerate(lines):
        output.append(line)
        stripped = line.strip()

        dep = None
        if stripped.startswith("FROM stagex/"):
            parts = stripped.split()
            if len(parts) >= 2:
                dep = parts[1].split("/")[1]
        elif stripped.startswith("FROM --platform=") and "stagex/" in stripped:
            parts = stripped.split()
            if len(parts) >= 3 and parts[2].startswith("stagex/"):
                dep = parts[2].split("/")[1]

        if dep is None:
            continue

        merged = resolver.image_directives(dep)
        final_merged = merged

        indent = len(line) - len(line.lstrip())
        pad = " " * indent

        # Inject ARG TARGETARCH so login shells can reference it
        output.append(f"{pad}ARG TARGETARCH\n")

        for env_entry in merged["env"]:
            output.append(f"{pad}ENV {env_entry}\n")

        if merged["shell"]:
            output.append(f"{pad}SHELL {format_shell_json(merged['shell'])}\n")

        # Reset ENTRYPOINT only if parent chain sets one AND remaining lines
        # don't define their own
        if merged["entrypoint"]:
            remaining = "".join(lines[i + 1:])
            if "ENTRYPOINT " not in remaining:
                output.append(f"{pad}ENTRYPOINT []\n")

        if merged["workingdir"] and "${" not in merged["workingdir"]:
            output.append(f"{pad}WORKDIR {merged['workingdir']}\n")

    write_metadata(stage, name, final_merged)
    return "".join(output)


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <stage> <name> <origin>", file=sys.stderr)
        sys.exit(1)

    stage, name, origin = sys.argv[1], sys.argv[2], sys.argv[3]
    containerfile = f"packages/{stage}/{origin}/Containerfile"

    resolver = MetadataResolver("packages")
    result = inject(containerfile, stage, name, resolver)
    sys.stdout.write(result)


if __name__ == "__main__":
    main()
