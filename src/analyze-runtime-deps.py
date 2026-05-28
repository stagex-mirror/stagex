#!/usr/bin/env python3
"""
Stagex Runtime Dependency Analyzer

This script:
1. Scans all packages in the out directory
2. Extracts OCI images to find binaries/libraries
3. Runs readelf to get library dependencies
4. Maps library dependencies to packages via file database
5. Generates runtime target stages for each Containerfile
   - Handles main package AND subpackages (package-*, package-subname, etc.)

Usage:
    python3 src/analyze-runtime-deps.py
"""

import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tarfile
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Set, Tuple, Optional

# Configuration
STAGEX_ROOT = Path(os.getcwd()) 
TEMP_DIR = STAGEX_ROOT / ".build-temp"
DB_PATH = TEMP_DIR / "package_files.db"
PACKAGES_DIR = STAGEX_ROOT / "packages"
OUT_DIR = STAGEX_ROOT / "out"

# "FROM <base> AS package[-<sub>]" package stages.
PKG_FROM_RE = re.compile(r'^FROM\s+\S+\s+AS\s+(package(?:-\S+)?)\s*$')
# Runtime target stages: "FROM package[-<sub>] AS runtime[-<sub>]".
# The "runtime" prefix lives in a separate namespace from "package", so a
# target stage never collides with a subpackage stage name (e.g. core/llvm
# can have an "llvm-runtime" subpackage stage AS package-llvm-runtime and
# a runtime target for the bare llvm stage AS runtime-llvm side by side).
RUN_FROM_RE = re.compile(r'^FROM\s+package(?:-\S+)?\s+AS\s+runtime(?:-\S+)?\s*$')

def setup_temp_dir():
    """Create temporary directory structure."""
    TEMP_DIR.mkdir(exist_ok=True)
    (TEMP_DIR / "extract").mkdir(exist_ok=True)
    print(f"✓ Temp directory ready: {TEMP_DIR}")


def get_package_names() -> List[str]:
    """Get list of all built package names from out directory."""
    packages = []
    for item in OUT_DIR.iterdir():
        if item.is_dir() and not item.name.startswith("bootstrap-stage"):
            packages.append(item.name)
    return sorted(packages)


def get_package_rootfs_tarball(package_name: str) -> Optional[Path]:
    """Find the layer tarball for a package's rootfs."""
    index_path = OUT_DIR / package_name / "index.json"
    if not index_path.exists():
        return None
    
    try:
        with open(index_path) as f:
            index = json.load(f)
        
        manifest_digest = None
        for m in index.get("manifests", []):
            manifest_digest = m["digest"]
            break
        
        if not manifest_digest:
            return None
        
        digest_hash = manifest_digest.split(":")[1]
        manifest_or_index_path = OUT_DIR / package_name / "blobs" / "sha256" / digest_hash
        
        if not manifest_or_index_path.exists():
            return None
        
        with open(manifest_or_index_path) as f:
            manifest_data = json.load(f)
        
        if manifest_data.get("mediaType") == "application/vnd.oci.image.index.v1+json":
            for m in manifest_data.get("manifests", []):
                if m.get("platform", {}).get("architecture") == "amd64":
                    manifest_digest = m["digest"]
                    break
                elif not manifest_digest:
                    manifest_digest = m["digest"]
            
            digest_hash = manifest_digest.split(":")[1]
            manifest_path = OUT_DIR / package_name / "blobs" / "sha256" / digest_hash
            
            with open(manifest_path) as f:
                manifest = json.load(f)
        else:
            manifest = manifest_data
        
        layers = manifest.get("layers", [])
        if not layers:
            return None
        
        layer_digest = layers[-1]["digest"].split(":")[1]
        layer_path = OUT_DIR / package_name / "blobs" / "sha256" / layer_digest
        
        return layer_path if layer_path.exists() else None
        
    except Exception:
        return None


def build_file_database():
    """Build SQLite database mapping files to packages."""
    print("\n=== Building file database ===")
    
    if DB_PATH.exists():
        DB_PATH.unlink()
    
    conn = sqlite3.connect(str(DB_PATH))
    cursor = conn.cursor()
    
    cursor.execute("""
        CREATE TABLE package_files (
            id INTEGER PRIMARY KEY,
            package_name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            file_type TEXT NOT NULL,
            is_executable INTEGER DEFAULT 0,
            is_library INTEGER DEFAULT 0
        )
    """)
    
    cursor.execute("CREATE INDEX idx_file_path ON package_files(file_path)")
    cursor.execute("CREATE INDEX idx_package ON package_files(package_name)")
    cursor.execute("CREATE INDEX idx_library ON package_files(is_library)")
    
    packages = get_package_names()
    print(f"Processing {len(packages)} packages...")
    
    total_files = 0
    for package_name in packages:
        tarball_path = get_package_rootfs_tarball(package_name)
        if not tarball_path:
            print(f"  ⚠ No tarball found for {package_name}")
            continue
        
        try:
            with tarfile.open(tarball_path, 'r:*') as tar:
                for member in tar.getmembers():
                    if member.isdir():
                        continue
                    
                    file_path = member.name
                    if file_path.startswith('/'):
                        file_path = file_path[1:]
                    
                    is_executable = member.isfile()
                    is_library = '.so' in file_path
                    
                    cursor.execute(
                        "INSERT INTO package_files (package_name, file_path, file_type, is_executable, is_library) VALUES (?, ?, ?, ?, ?)",
                        (package_name, file_path, "regular" if member.isfile() else "symlink", 
                         1 if is_executable else 0, 1 if is_library else 0)
                    )
                    total_files += 1
                            
        except Exception as e:
            print(f"  ⚠ Error processing {package_name}: {e}")
            continue
    
    conn.commit()
    print(f"✓ Database built: {total_files} files from {len(packages)} packages")
    print(f"  Database: {DB_PATH}")
    
    return conn


def extract_and_scan_package(conn: sqlite3.Connection, package_name: str) -> Dict[str, List[str]]:
    """
    Extract package tarball and scan binaries/libraries for dependencies.
    Returns dict mapping file_path -> list of library dependencies (names only)
    """
    tarball_path = get_package_rootfs_tarball(package_name)
    if not tarball_path:
        return {}
    
    extract_dir = TEMP_DIR / "extract" / package_name
    if extract_dir.exists():
        shutil.rmtree(extract_dir)
    extract_dir.mkdir(parents=True, exist_ok=True)
    
    dependencies = defaultdict(list)
    
    try:
        with tarfile.open(tarball_path, 'r:*') as tar:
            try:
                tar.extractall(extract_dir, filter='tar')
            except (PermissionError, tarfile.SpecialFileError):
                return dependencies
        
        cursor = conn.cursor()
        cursor.execute("""
            SELECT file_path FROM package_files
            WHERE package_name = ? AND (is_executable = 1 OR is_library = 1)
        """, (package_name,))
        
        file_paths = [row[0] for row in cursor.fetchall()]
        
        for file_path in file_paths:
            full_path = extract_dir / file_path
            if not full_path.exists() or not full_path.is_file():
                continue
            
            try:
                with open(full_path, 'rb') as f:
                    magic = f.read(4)
                    if magic != b'\x7fELF':
                        continue
            except:
                continue
            
            try:
                result = subprocess.run(
                    ["readelf", "-d", str(full_path)],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if result.returncode == 0:
                    for line in result.stdout.splitlines():
                        if "NEEDED" in line:
                            match = re.search(r'\[([^\]]+)\]', line)
                            if match:
                                lib_name = match.group(1)
                                dependencies[file_path].append(lib_name)
                                
            except subprocess.TimeoutExpired:
                continue
            except Exception:
                continue
                
    finally:
        if extract_dir.exists():
            shutil.rmtree(extract_dir)
    
    return dependencies


# Sonames whose canonical provider isn't derivable from the name. Each entry
# maps a regex against the bare soname (e.g. "libz.so.1") to the package the
# runtime target should pull in. The package still has to exist in the DB -
# if it doesn't, we fall through to the generic lookup.
CANONICAL_PROVIDERS = [
    (re.compile(r'^libc\.so'), 'core-musl'),
    (re.compile(r'^libz\.so'), 'core-zlib'),
    (re.compile(r'^libssl\.so'), 'core-openssl'),
    (re.compile(r'^libcrypto\.so'), 'core-openssl'),
    (re.compile(r'^libc\+\+\.so'), 'core-libcxx'),
    (re.compile(r'^libc\+\+abi\.so'), 'core-libcxxabi'),
    (re.compile(r'^libstdc\+\+\.so'), 'core-gcc'),
    (re.compile(r'^libgcc_s\.so'), 'core-gcc'),
    (re.compile(r'^libffi\.so'), 'core-libffi'),
    (re.compile(r'^libunwind(-[^.]+)?\.so'), 'core-libunwind'),
    (re.compile(r'^libLLVM\.so'), 'core-llvm'),
    (re.compile(r'^libevent(-[^.]+)?\.so'), 'user-libevent'),
    (re.compile(r'^libnftnl\.so'), 'user-libnftnl'),
]


def resolve_library_to_package(cursor: sqlite3.Cursor, lib_name: str) -> str:
    """Find which package provides a library.

    Canonical providers win when they're present in the DB. Otherwise fall back
    to the file-path lookup with a deterministic tie-break: prefer core-* over
    pallet-* over user-*, then shortest package name.
    """
    for pattern, pkg in CANONICAL_PROVIDERS:
        if pattern.match(lib_name):
            cursor.execute(
                "SELECT 1 FROM package_files WHERE package_name = ? LIMIT 1",
                (pkg,),
            )
            if cursor.fetchone():
                return pkg

    cursor.execute("""
        SELECT DISTINCT package_name FROM package_files
        WHERE file_path LIKE ? AND is_library = 1
    """, (f"%/{lib_name}",))
    candidates = [r[0] for r in cursor.fetchall()]
    if not candidates:
        return None

    tier = {'core-': 0, 'pallet-': 1, 'user-': 2}
    def rank(name):
        return (next((v for p, v in tier.items() if name.startswith(p)), 3),
                len(name), name)
    return min(candidates, key=rank)


def analyze_dependencies(conn: sqlite3.Connection):
    """Analyze all packages and build dependency graph."""
    print("\n=== Analyzing runtime dependencies ===")
    
    cursor = conn.cursor()
    packages = get_package_names()
    
    package_lib_deps = defaultdict(set)
    
    for i, package_name in enumerate(packages):
        print(f"  [{i+1}/{len(packages)}] {package_name}")
        
        deps = extract_and_scan_package(conn, package_name)
        
        for file_path, lib_names in deps.items():
            for lib_name in lib_names:
                package_lib_deps[package_name].add(lib_name)
        
        if package_lib_deps[package_name]:
            libs = list(package_lib_deps[package_name])[:5]
            print(f"    Found libs: {libs}")
    
    print("\n=== Resolving library dependencies to packages ===")
    
    package_deps = defaultdict(set)
    
    for package_name, lib_names in package_lib_deps.items():
        for lib_name in lib_names:
            provider = resolve_library_to_package(cursor, lib_name)
            if "gcc" in package_name and provider == "core-musl":
              provider = "core-gcc"
            if provider and provider != package_name:
                package_deps[package_name].add(provider)
                print(f"  {package_name} -> {provider} (via {lib_name})")

    # Expand each package's dep set to its transitive closure. Without this, a
    # -runtime block ships only direct providers; the dynamic loader fails when a
    # direct dep itself links to a lib that's not in the closure (e.g.
    # iproute2 -> libelf -> libz).
    print("\n=== Computing transitive closure ===")
    def closure(pkg, seen):
        if pkg in seen:
            return set()
        seen.add(pkg)
        out = set()
        for d in package_deps.get(pkg, ()):
            if d == pkg or d in seen:
                continue
            out.add(d)
            out |= closure(d, seen)
        return out

    transitive = {p: closure(p, set()) for p in list(package_deps.keys())}
    for p, deps in transitive.items():
        added = deps - package_deps[p]
        if added:
            print(f"  {p} += {sorted(added)}")
        package_deps[p] = deps

    return package_deps


def get_package_name_from_path(containerfile_path: Path) -> str:
    """Extract full package name from Containerfile path."""
    parts = containerfile_path.relative_to(STAGEX_ROOT).parts
    if len(parts) >= 3:
        return f"{parts[1]}-{parts[2]}"
    return ""


def strip_run_blocks(lines: List[str]) -> List[str]:
    """Remove every existing package-family -runtime block.

    A -runtime block is a line matching RUN_FROM_RE followed by its COPY lines and
    trailing blank lines. -runtime stages on a non-package base are left untouched.
    """
    out: List[str] = []
    i = 0
    while i < len(lines):
        if RUN_FROM_RE.match(lines[i]):
            i += 1
            while i < len(lines) and lines[i].startswith("COPY"):
                i += 1
            while i < len(lines) and lines[i].strip() == "":
                i += 1
            continue
        out.append(lines[i])
        i += 1
    return out


def normalize_blank_lines(lines: List[str]) -> List[str]:
    """Collapse runs of 2+ blank lines into one and trim leading/trailing blanks."""
    out: List[str] = []
    prev_blank = False
    for line in lines:
        blank = line.strip() == ""
        if blank and prev_blank:
            continue
        out.append(line)
        prev_blank = blank
    while out and out[0].strip() == "":
        out.pop(0)
    while out and out[-1].strip() == "":
        out.pop()
    return out


def generate_package_run_blocks(package_deps: Dict[str, Set[str]]):
    """Generate runtime target stages for all Containerfiles including subpackages."""
    print("\n=== Generating runtime targets ===")
    
    # Find all Containerfiles
    containerfiles = []
    for pkg_dir in PACKAGES_DIR.iterdir():
        if pkg_dir.is_dir():
            for subdir in pkg_dir.iterdir():
                if subdir.is_dir():
                    cf = subdir / "Containerfile"
                    if cf.exists():
                        containerfiles.append(cf)
    
    print(f"Found {len(containerfiles)} Containerfiles")
    
    updated = 0
    for cf_path in containerfiles:
        content = cf_path.read_text()

        # Each stage in this file is published as its own out/ image, so it
        # has its own per-stage deps. "package" -> out/<cat>-<dir>/,
        # "package-<sub>" -> out/<cat>-<sub>/. Same rule as discover_targets()
        # in verify-runtime-deps.py.
        parts = cf_path.relative_to(STAGEX_ROOT).parts
        cat, dirname = parts[1], parts[2]

        def stage_out_name(stage: str) -> str:
            if stage == "package":
                return f"{cat}-{dirname}"
            return f"{cat}-{stage[len('package-'):]}"

        # Strip every existing runtime target stage, then regenerate exactly
        # one fresh runtime target per package stage from that stage's own deps.
        lines = strip_run_blocks(content.splitlines())

        # Collect all subpackage stage names that survive stripping. If a
        # would-be target name collides with one, skip emission (defensive;
        # the parallel namespaces make this unreachable in practice).
        existing_stage_names = set()
        for ln in lines:
            m = PKG_FROM_RE.match(ln)
            if m:
                existing_stage_names.add(m.group(1))

        new_lines = []
        any_deps = False

        i = 0
        while i < len(lines):
            line = lines[i]
            match = PKG_FROM_RE.match(line)
            if match:
                package_stage = match.group(1)
                stage_deps = package_deps.get(stage_out_name(package_stage), set())
                # Target name lives in the parallel "runtime" namespace:
                # package -> runtime, package-<sub> -> runtime-<sub>.
                target_name = "runtime" + package_stage[len("package"):]
                # Emit the package block (FROM + subsequent COPY lines).
                new_lines.append(line)
                i += 1
                while i < len(lines) and lines[i].startswith("COPY"):
                    new_lines.append(lines[i])
                    i += 1
                if stage_deps and target_name not in existing_stage_names:
                    any_deps = True
                    new_lines.append("")
                    new_lines.append(f"FROM {package_stage} AS {target_name}")
                    for dep in sorted(stage_deps):
                        new_lines.append(f"COPY --from=stagex/{dep} . /")
                    new_lines.append("")
                continue

            new_lines.append(line)
            i += 1

        # If no stage had any deps, leave the file (and any hand-maintained
        # runtime target stages) untouched.
        if not any_deps:
            print(f"  ⏭ {cf_path.relative_to(STAGEX_ROOT)} (no deps)")
            continue

        new_content = "\n".join(normalize_blank_lines(new_lines)) + "\n"

        if new_content == content:
            print(f"  = {cf_path.relative_to(STAGEX_ROOT)} (unchanged)")
            continue

        cf_path.write_text(new_content)
        print(f"  ✓ {cf_path.relative_to(STAGEX_ROOT)}")
        updated += 1

    print(f"\n✓ Updated {updated} Containerfiles with runtime targets")


def main():
    """Main entry point."""
    print("=== Stagex Runtime Dependency Analyzer ===\n")
    
    setup_temp_dir()
    conn = build_file_database()
    package_deps = analyze_dependencies(conn)
    generate_package_run_blocks(package_deps)
    
    conn.close()
    
    print("\n=== Complete ===")
    print(f"Temp artifacts: {TEMP_DIR}")
    print("Note: Only Containerfile changes should be committed")


if __name__ == "__main__":
    main()
