#!/usr/bin/env python3
"""
Stagex Runtime Dependency Verifier

Builds a minimal image for each package's `runtime` target stage (the
auto-generated runtime-dependency stage) and runs every binary the package
provides inside it. A binary that fails to start - missing shared library,
missing symbol, or missing script interpreter - means the runtime target
is incomplete.

The minimal image is composed purely from the OCI layouts already in `out/`:
a spec `FROM <package image>` + `COPY --from=stagex/<dep> . /` is piped to
`docker build` on stdin. Nothing is written to disk or added to any package.

Usage:
    python3 src/verify-runtime-deps.py                  # all packages
    python3 src/verify-runtime-deps.py core-bash core-grep
"""

import argparse
import importlib.util
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import uuid
from collections import namedtuple
from pathlib import Path

# Reuse helpers from the sibling analyzer (hyphenated filename -> importlib).
_ANALYZER = Path(__file__).resolve().parent / "analyze-runtime-deps.py"
_spec = importlib.util.spec_from_file_location("analyze_runtime_deps", _ANALYZER)
analyzer = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(analyzer)

STAGEX_ROOT = analyzer.STAGEX_ROOT
OUT_DIR = analyzer.OUT_DIR
PACKAGES_DIR = analyzer.PACKAGES_DIR
DB_PATH = analyzer.DB_PATH
PKG_FROM_RE = analyzer.PKG_FROM_RE

# Runtime target stages: "FROM package[-<sub>] AS runtime[-<sub>]".
# The "runtime" prefix is a parallel namespace to "package", so a runtime
# target stage can never be confused with a subpackage stage (e.g. core/llvm
# has the llvm-runtime subpackage at AS package-llvm-runtime, distinct from
# any AS runtime[-...] target).
RUN_STAGE_RE = re.compile(r'^FROM\s+package(?:-\S+)?\s+AS\s+(runtime(?:-\S+)?)\s*$')
# Captures a stagex dependency from a "COPY --from=stagex/<dep> . /" line.
COPY_DEP_RE = re.compile(r'^COPY\s+--from=stagex/(\S+)\s')

# Substrings the musl dynamic loader emits when a runtime target is incomplete.
LOADER_ERRORS = (
    "error loading shared library",
    "error relocating",
    "symbol not found",
)
# Substrings indicating an unrunnable file shipped under usr/bin or usr/sbin -
# wrong architecture, plain text without a shebang, or no exec bit. These say
# nothing about the runtime target, so we skip rather than fail them.
SKIP_ERRORS = (
    "exec format error",
    "permission denied",
)
# Substrings indicating the binary started but its script interpreter is
# missing - a real runtime-target problem.
EXEC_ERRORS = (
    "no such file or directory",
)

Target = namedtuple("Target", "out_name containerfile stage deps")


def discover_targets():
    """Find every package stage across all Containerfiles and its runtime deps."""
    targets = []
    seen = set()
    for cf in sorted(PACKAGES_DIR.glob("*/*/Containerfile")):
        cat = cf.relative_to(PACKAGES_DIR).parts[0]
        dirname = cf.parent.name
        lines = cf.read_text().splitlines()

        # Map each package stage -> list of its runtime block dependencies.
        run_deps = {}
        i = 0
        while i < len(lines):
            m = RUN_STAGE_RE.match(lines[i])
            if not m:
                i += 1
                continue
            # target "runtime[-<sub>]" maps back to the package stage
            # "package[-<sub>]" that supplied its base.
            base_stage = "package" + m.group(1)[len("runtime"):]
            deps = []
            i += 1
            while i < len(lines) and lines[i].startswith("COPY"):
                cm = COPY_DEP_RE.match(lines[i])
                if cm:
                    deps.append(cm.group(1))
                i += 1
            run_deps[base_stage] = deps

        # Collect package stages. Closures live in a parallel "runtime[-<sub>]"
        # namespace and therefore never match PKG_FROM_RE.
        for line in lines:
            m = PKG_FROM_RE.match(line)
            if not m:
                continue
            stage = m.group(1)
            if stage == "package":
                out_name = f"{cat}-{dirname}"
            else:  # package-<sub>
                out_name = f"{cat}-{stage[len('package-'):]}"
            if out_name.startswith("bootstrap-stage"):
                continue  # bootstrap stages are not distributable packages
            if out_name in seen:
                continue
            seen.add(out_name)
            targets.append(Target(out_name, cf, stage, run_deps.get(stage, [])))
    return targets


def get_db(rebuild):
    """Open the file database read-only, building it first if needed."""
    if rebuild or not DB_PATH.exists():
        print("Building file database (scans all out/ layers, may take a while)...")
        analyzer.setup_temp_dir()
        analyzer.build_file_database().close()
    return sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)


def list_binaries(conn, out_name):
    """Return regular files under usr/bin and usr/sbin (ELF binaries and scripts)."""
    cur = conn.cursor()
    cur.execute(
        "SELECT file_path FROM package_files "
        "WHERE package_name=? AND file_type='regular' "
        "AND (file_path LIKE 'usr/bin/%' OR file_path LIKE 'usr/sbin/%')",
        (out_name,),
    )
    return sorted(r[0] for r in cur.fetchall())


def summarize_build_error(stderr):
    """Condense a docker build failure to one informative line."""
    lines = [ln.strip() for ln in stderr.splitlines() if ln.strip()]
    for ln in lines:
        m = re.search(r'cannot replace to directory (\S+) with file', ln)
        if m:
            path = re.sub(r'^.*/buildkit\d+/', '/', m.group(1))
            return (f"layer conflict at {path}: shipped as a real directory by "
                    f"one package and as a symlink by another")
    for ln in reversed(lines):
        if ln.lower().startswith("error") or ": failed to " in ln.lower():
            return ln
    return lines[-1] if lines else "unknown build error"


def build_image(target, ctx_dir):
    """Build the minimal runtime image from out/ OCI layouts. Returns (tag, error)."""
    if not (OUT_DIR / target.out_name).is_dir():
        return None, f"missing out/{target.out_name}"
    missing = [d for d in target.deps if not (OUT_DIR / d).is_dir()]
    if missing:
        return None, f"missing out/ dep dirs: {missing}"

    spec = "FROM base\n" + "".join(
        f"COPY --from=stagex/{d} . /\n" for d in target.deps
    )
    tag = f"stagex-verify/{target.out_name}:runtime"
    cmd = [
        "docker", "build",
        "--provenance=false",
        "-t", tag,
        "-f", "-",
        "--build-context", f"base=oci-layout://./out/{target.out_name}",
    ]
    for d in target.deps:
        cmd += ["--build-context", f"stagex/{d}=oci-layout://./out/{d}"]
    cmd.append(ctx_dir)

    env = {**os.environ, "DOCKER_BUILDKIT": "1"}
    try:
        r = subprocess.run(cmd, input=spec, text=True, errors="replace",
                           capture_output=True, cwd=STAGEX_ROOT, env=env,
                           timeout=600)
    except subprocess.TimeoutExpired:
        return None, "docker build timed out"
    if r.returncode != 0:
        return None, summarize_build_error(r.stderr)
    return tag, None


def classify(returncode, output):
    """Classify a binary run: PASS, FAIL, or SKIP."""
    low = output.lower()
    if any(s in low for s in LOADER_ERRORS):
        return "FAIL"
    # docker/runc rejected the file before it ever ran (no exec bit, wrong
    # arch, plain text). Not a runtime-target issue - skip and don't count it.
    if returncode in (125, 126, 127) and any(s in low for s in SKIP_ERRORS):
        return "SKIP"
    # A real exec failure (missing script interpreter) always carries one of
    # these messages. An exit code alone is not enough: a program that started
    # and then exited non-zero - busybox printing "applet not found", or any
    # tool rejecting --version - is a PASS.
    if returncode in (125, 126, 127) and any(s in low for s in EXEC_ERRORS):
        return "FAIL"
    return "PASS"


def extract_detail(output):
    """Pull the missing library / symbol / reason out of a failure's output."""
    m = re.search(r'Error loading shared library ([^:]+):', output)
    if m:
        return f"missing library: {m.group(1).strip()}"
    m = re.search(r'Error relocating \S+: ([^:]+): symbol not found', output)
    if m:
        return f"missing symbol: {m.group(1).strip()}"
    last = [ln for ln in output.strip().splitlines() if ln.strip()]
    return last[-1].strip() if last else "unknown failure"


def run_binary(tag, file_path, timeout):
    """Run one binary inside the runtime image. Returns (status, output)."""
    abspath = "/" + file_path.lstrip("/")
    name = "sxv-" + uuid.uuid4().hex[:12]
    cmd = ["docker", "run", "--rm", "--name", name, "--network=none",
           "--entrypoint", abspath, tag, "--version"]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired:
        subprocess.run(["docker", "rm", "-f", name], capture_output=True)
        return "WARN", "timeout"
    output = r.stdout + r.stderr
    return classify(r.returncode, output), output


def main():
    ap = argparse.ArgumentParser(
        description="Verify auto-generated runtime target stages")
    ap.add_argument("packages", nargs="*",
                    help="limit to these out/ package names")
    ap.add_argument("--timeout", type=int, default=20,
                    help="per-binary run timeout in seconds (default: 20)")
    ap.add_argument("--keep-images", action="store_true",
                    help="do not delete the built verify images")
    ap.add_argument("--rebuild-db", action="store_true",
                    help="rebuild the file database before verifying")
    args = ap.parse_args()

    if not (STAGEX_ROOT / "packages").is_dir() or not OUT_DIR.is_dir():
        sys.exit("ERROR: run this script from the stagex repo root")
    if not shutil.which("docker"):
        sys.exit("ERROR: docker not found on PATH")

    conn = get_db(args.rebuild_db)

    targets = discover_targets()
    if args.packages:
        wanted = set(args.packages)
        targets = [t for t in targets if t.out_name in wanted]
        for name in sorted(wanted - {t.out_name for t in targets}):
            print(f"  ⚠ no package stage found for '{name}'")
    targets.sort(key=lambda t: t.out_name)

    print(f"=== Verifying {len(targets)} runtime target stages ===\n")

    pkg_pass = pkg_fail = pkg_error = 0
    bin_pass = bin_fail = bin_warn = bin_skip = 0
    failures = []      # (out_name, binary, detail) - binaries that failed to run
    build_errors = []  # (out_name, detail) - runtime image could not be built
    built_tags = []

    ctx_dir = tempfile.mkdtemp(prefix="sxv-ctx-")
    try:
        for idx, t in enumerate(targets, 1):
            prefix = f"[{idx}/{len(targets)}] {t.out_name}"

            tag, err = build_image(t, ctx_dir)
            if not tag:
                print(f"{prefix} ERROR  ({err})")
                pkg_error += 1
                build_errors.append((t.out_name, err))
                continue
            built_tags.append(tag)

            try:
                binaries = list_binaries(conn, t.out_name)
                if not binaries:
                    print(f"{prefix} INFO   (no binaries)")
                    continue

                passed = failed = warned = skipped = 0
                local_failures = []
                for b in binaries:
                    status, output = run_binary(tag, b, args.timeout)
                    if status == "PASS":
                        passed += 1
                    elif status == "WARN":
                        warned += 1
                    elif status == "SKIP":
                        skipped += 1
                    else:
                        failed += 1
                        local_failures.append((b, extract_detail(output)))

                bin_pass += passed
                bin_fail += failed
                bin_warn += warned
                bin_skip += skipped

                if failed:
                    pkg_fail += 1
                    print(f"{prefix} FAIL   "
                          f"({passed}/{len(binaries)} ok, {failed} failed)")
                    for b, detail in local_failures:
                        print(f"           {b}: {detail}")
                        failures.append((t.out_name, b, detail))
                else:
                    pkg_pass += 1
                    extras = []
                    if warned:
                        extras.append(f"{warned} timeout")
                    if skipped:
                        extras.append(f"{skipped} skipped")
                    extra = (", " + ", ".join(extras)) if extras else ""
                    print(f"{prefix} PASS   "
                          f"({passed}/{len(binaries)} ok{extra})")
            finally:
                if not args.keep_images:
                    subprocess.run(["docker", "image", "rm", "-f", tag],
                                   capture_output=True)
    finally:
        if built_tags and not args.keep_images:
            subprocess.run(["docker", "image", "rm", "-f", *built_tags],
                           capture_output=True)
        shutil.rmtree(ctx_dir, ignore_errors=True)
        conn.close()

    print("\n=== Summary ===")
    print(f"Packages : {pkg_pass} pass, {pkg_fail} fail, {pkg_error} build-error")
    print(f"Binaries : {bin_pass} pass, {bin_fail} fail, {bin_warn} timeout, {bin_skip} skipped")
    if build_errors:
        print("\nUnbuildable runtime targets:")
        for out_name, detail in build_errors:
            print(f"  {out_name}: {detail}")
    if failures:
        print("\nIncomplete runtime targets:")
        for out_name, binary, detail in failures:
            print(f"  {out_name}  {binary}: {detail}")
    sys.exit(1 if (pkg_fail or pkg_error) else 0)


if __name__ == "__main__":
    main()
