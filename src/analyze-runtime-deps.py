#!/usr/bin/env python3
"""
Stagex Runtime Dependency Analyzer

This script:
1. Scans all packages in the out directory
2. Extracts OCI images to find binaries/libraries
3. Runs readelf to get library dependencies
4. Maps library dependencies to packages via file database
5. Generates package-run blocks for each Containerfile
   - Handles main package AND subpackages (package-*, package-subname, etc.)

Usage:
    python3 src/analyze-runtime-deps.py
"""

import os
import sqlite3
import subprocess
import sys
import shutil
import json
import tarfile
import re
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Set, Tuple, Optional

# Configuration
STAGEX_ROOT = Path("/home/lrvick/Sources/stagex")
TEMP_DIR = STAGEX_ROOT / ".build-temp"
DB_PATH = TEMP_DIR / "package_files.db"
PACKAGES_DIR = STAGEX_ROOT / "packages"
OUT_DIR = STAGEX_ROOT / "out"


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
            LIMIT 100
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


def resolve_library_to_package(cursor: sqlite3.Cursor, lib_name: str) -> str:
    """Find which package provides a library."""
    cursor.execute("""
        SELECT DISTINCT package_name FROM package_files 
        WHERE file_path LIKE ? AND is_library = 1
        LIMIT 1
    """, (f"%/{lib_name}",))
    
    row = cursor.fetchone()
    if row:
        return row[0]
    
    if '.so' in lib_name:
        cursor.execute("""
            SELECT DISTINCT package_name FROM package_files 
            WHERE file_path LIKE ? AND is_library = 1
            LIMIT 1
        """, (f"%/{lib_name}",))
        
        row = cursor.fetchone()
        if row:
            return row[0]
    
    return None


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
            if provider and provider != package_name:
                package_deps[package_name].add(provider)
                print(f"  {package_name} -> {provider} (via {lib_name})")
    
    return package_deps


def get_package_name_from_path(containerfile_path: Path) -> str:
    """Extract full package name from Containerfile path."""
    parts = containerfile_path.relative_to(STAGEX_ROOT).parts
    if len(parts) >= 3:
        return f"{parts[1]}-{parts[2]}"
    return ""


def generate_package_run_blocks(package_deps: Dict[str, Set[str]]):
    """Generate package-run blocks for all Containerfiles including subpackages."""
    print("\n=== Generating package-run blocks ===")
    
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
        
        # Check if already has package-run blocks
        if "AS package-run" in content:
            print(f"  ⏭ {cf_path.relative_to(STAGEX_ROOT)} (already has package-run)")
            continue
        
        package_name = get_package_name_from_path(cf_path)
        deps = package_deps.get(package_name, set())
        
        if not deps:
            print(f"  ⏭ {cf_path.relative_to(STAGEX_ROOT)} (no deps)")
            continue
        
        # Insert package-run block BEFORE each "FROM ... AS package-" line
        lines = content.splitlines()
        new_lines = []
        
        for line in lines:
            # Check if this is a "FROM ... AS package-*" line
            match = re.match(r'^(FROM\s+(\S+)\s+AS\s+(package(?:-\S+)?))', line)
            if match:
                from_stage = match.group(2)
                package_stage = match.group(3)
                
                # Add package-run block that FROMs scratch for minimal runtime image
                if deps:
                    new_lines.append(f"")
                    new_lines.append(f"FROM scratch AS {package_stage}-run")
                    
                    for dep in sorted(deps):
                        new_lines.append(f"COPY --from=stagex/{dep} . /")
                    
                    new_lines.append(f"")
            
            new_lines.append(line)
        
        new_content = "\n".join(new_lines) + "\n"
        cf_path.write_text(new_content)
        print(f"  ✓ {cf_path.relative_to(STAGEX_ROOT)}")
        updated += 1
    
    print(f"\n✓ Updated {updated} Containerfiles with package-run blocks")


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
