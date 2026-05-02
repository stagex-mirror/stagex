#!/usr/bin/env python3
"""
update.py - Check for package updates and build them in order

Usage:
    python3 src/update.py

Requirements:
    - release-monitoring.org API access
    - Docker available for building packages
"""

import os
import sys
import json
import subprocess
import re
import time
import hashlib
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple
import argparse
from datetime import datetime, timedelta
import requests
import sqlite3

# Setup logging to file
LOG_DIR = Path("/home/lrvick/Sources/stagex/.logs")
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / f"update_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

def log(message, level="INFO"):
    """Log message to both stdout and log file."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    formatted = f"[{timestamp}] [{level}] {message}"
    print(formatted, flush=True)
    with open(LOG_FILE, 'a') as f:
        f.write(formatted + "\n")
        f.flush()


def get_build_order() -> List[str]:
    """Get packages in actual build order by running a dry-run make."""
    try:
        result = subprocess.run(
            ["make", "-n", "all"],
            cwd="/home/lrvick/Sources/stagex",
            capture_output=True,
            text=True,
            env={**os.environ, "NOCACHE": "1"}
        )
        
        if result.returncode != 0:
            log(f"  Warning: make dry-run failed: {result.stderr}", "WARNING")
            return []
        
        packages = []
        for line in result.stdout.split('\n'):
            match = re.search(r'rm -rf out/([a-z]+-[a-zA-Z0-9_-]+)', line)
            if match:
                packages.append(match.group(1))
        
        seen = set()
        unique_packages = []
        for pkg in packages:
            if pkg not in seen:
                seen.add(pkg)
                unique_packages.append(pkg)
        
        return unique_packages
    
    except Exception as e:
        log(f"  Error getting build order: {e}", "ERROR")
        return []


def get_release_monitoring_data() -> Dict[str, dict]:
    """Fetch all project data from release-monitoring.org with SQLite caching."""
    cache_db = Path("/home/lrvick/Sources/stagex/out/relmon.db")
    cache_dir = cache_db.parent
    cache_dir.mkdir(parents=True, exist_ok=True)
    
    # Use the stagex-specific endpoint
    api_url = "https://release-monitoring.org/api/v2/packages/?distribution=stagex"
    cache_age_limit = timedelta(hours=24)
    
    def fetch_and_cache():
        """Fetch fresh data and store in cache."""
        log(f"  Fetching fresh release-monitoring data...")
        response = requests.get(api_url, timeout=120)
        if response.status_code != 200:
            log(f"  Failed to fetch release-monitoring API: {response.status_code}", "ERROR")
            return None
        
        data = response.json()
        
        # Store in SQLite
        conn = sqlite3.connect(str(cache_db))
        cursor = conn.cursor()
        
        # Create table if not exists
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS packages (
                rowid INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE,
                data TEXT,
                fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Clear old data
        cursor.execute('DELETE FROM packages')
        
        # Insert packages
        for pkg in data.get("items", []):
            cursor.execute(
                'INSERT OR REPLACE (name, data, fetched_at) VALUES (?, ?, ?)',
                (
                    pkg.get("name", "").lower(),
                    json.dumps(pkg),
                    datetime.now()
                )
            )
        
        conn.commit()
        conn.close()
        
        return data
    
    # Check if cache exists and is fresh
    if cache_db.exists():
        conn = sqlite3.connect(str(cache_db))
        cursor = conn.cursor()
        
        cursor.execute('SELECT fetched_at FROM packages LIMIT 1')
        result = cursor.fetchone()
        conn.close()
        
        if result:
            cache_time = datetime.fromisoformat(result[0])
            if datetime.now() - cache_time < cache_age_limit:
                log(f"  Using cached release-monitoring data (fetched {cache_time})")
            else:
                log(f"  Cache is older than 24h, refreshing...")
                data = fetch_and_cache()
                if data is None:
                    log(f"  Using stale cache due to fetch failure", "WARNING")
                    data = get_cached_data(cache_db)
                else:
                    log(f"  Cache refreshed successfully")
        else:
            data = fetch_and_cache()
    else:
        data = fetch_and_cache()
    
    if data is None:
        data = get_cached_data(cache_db)
    
    if data is None:
        log(f"  No release-monitoring data available", "ERROR")
        return {}
    
    # Index by package name (lowercase for matching)
    packages = {}
    for pkg in data.get("items", []):
        name = pkg.get("name", "").lower()
        if name:
            packages[name] = pkg
    
    log(f"  Indexed {len(packages)} packages from release-monitoring.org")
    return packages


def get_cached_data(cache_db: Path) -> Optional[dict]:
    """Get data from cache if available."""
    if not cache_db.exists():
        return None
    
    try:
        conn = sqlite3.connect(str(cache_db))
        cursor = conn.cursor()
        
        packages = []
        cursor.execute('SELECT data FROM packages')
        for row in cursor.fetchall():
            pkg = json.loads(row[0])
            packages.append(pkg)
        
        conn.close()
        
        return {"results": packages}
    except Exception as e:
        log(f"  Error reading cache: {e}", "ERROR")
        return None


def find_package_in_monitoring(package_name: str, projects: Dict[str, dict]) -> Optional[dict]:
    """Find a package in release-monitoring by name."""
    pkg_lower = package_name.lower()
    
    # Direct match
    if pkg_lower in projects:
        return projects[pkg_lower]
    
    # Try with hyphens vs underscores
    if '-' in pkg_lower:
        pkg_lower = pkg_lower.replace('-', '_')
        if pkg_lower in projects:
            return projects[pkg_lower]
    
    # Try with underscores vs hyphens
    if '_' in package_name.lower():
        pkg_lower = package_name.lower().replace('_', '-')
        if pkg_lower in projects:
            return projects[pkg_lower]
    
    return None


def get_latest_version_from_package(pkg: dict, current_version: str) -> Optional[str]:
    """Get the latest version from a package, different from current."""
    latest = pkg.get("stable_version")
    if not latest:
        return None
    
    # Check if it's different from current
    if latest == current_version:
        return None
    
    return latest


def get_download_url_from_package(pkg: dict, version: str) -> Optional[str]:
    """Get the download URL for a specific version."""
    # Use project name to construct download URL
    project = pkg.get("project", "")
    if not project:
        return None
    
    # Try to get from ecosystem
    ecosystem = pkg.get("ecosystem", "")
    
    # Common patterns based on ecosystem
    if "github.com" in ecosystem:
        # GitHub releases
        repo = ecosystem.rstrip("/").split("/")[-2:]
        if len(repo) >= 2:
            return f"https://github.com/{repo[0]}/{repo[1]}/releases/download/{version}/{project}-{version}.tar.gz"
    
    elif "savannah.gnu.org" in ecosystem or "savannah.nongnu.org" in ecosystem:
        # GNU/NGNU packages
        return f"https://download.savannah.gnu.org/releases/{project}/{project}-{version}.tar.gz"
    
    elif ecosystem == "pypi":
        # PyPI packages
        return f"https://files.pythonhosted.org/packages/source/{version[0]}/{project}/{project}-{version}.tar.gz"
    
    # Fallback: try to construct from homepage
    homepage = ecosystem
    if homepage:
        if homepage.endswith("/"):
            return homepage + f"{project}-{version}.tar.gz"
        else:
            return homepage + f"/{project}-{version}.tar.gz"
    
    return None


def download_archive(url: str, dest: Path) -> bool:
    """Download archive from URL."""
    try:
        log(f"  Downloading from {url}")
        response = requests.get(url, timeout=300, stream=True)
        if response.status_code != 200:
            log(f"  Failed to download from {url}: {response.status_code}", "ERROR")
            return False
        
        with open(dest, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        log(f"  Download complete: {dest}")
        return True
    except Exception as e:
        log(f"  Download error: {e}", "ERROR")
        return False


def compute_sha256(file_path: Path) -> str:
    """Compute SHA256 hash of file."""
    sha256 = hashlib.sha256()
    with open(file_path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            sha256.update(chunk)
    return sha256.hexdigest()


def update_package_toml(package_path: Path, new_version: str, new_sha256: str) -> bool:
    """Update package.toml with new version and sha256."""
    toml_file = package_path / "package.toml"
    
    if not toml_file.exists():
        log(f"  package.toml not found at {toml_file}", "ERROR")
        return False
    
    content = toml_file.read_text()
    
    # Update version
    version_pattern = r'^version\s*=\s*["\']([^"\']+)["\']'
    content = re.sub(version_pattern, f'version = "{new_version}"', content, flags=re.MULTILINE)
    
    # Update sha256
    sha256_pattern = r'^sha256\s*=\s*["\']([^"\']+)["\']'
    content = re.sub(sha256_pattern, f'sha256 = "{new_sha256}"', content, flags=re.MULTILINE)
    
    toml_file.write_text(content)
    log(f"  Updated package.toml with version {new_version}")
    return True


def build_package(package_target: str) -> bool:
    """Build a package."""
    try:
        clean_cmd = f"cd /home/lrvick/Sources/stagex && make clean-{package_target}"
        log(f"Running: {clean_cmd}")
        clean_proc = subprocess.Popen(clean_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        clean_out, clean_err = clean_proc.communicate()
        clean_ret = clean_proc.returncode
        
        log(f"Clean exit code: {clean_ret}")
        
        # Build with process monitoring
        build_cmd = f"cd /home/lrvick/Sources/stagex && make {package_target}"
        log(f"Running: {build_cmd}")
        
        build_proc = subprocess.Popen(build_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
        # Monitor the process until completion
        last_activity = time.time()
        idle_count = 0
        while build_proc.poll() is None:
            time.sleep(5)
            # Check if process is still alive (building)
            if build_proc.poll() is not None:
                break
            # Process is still running, continue monitoring
            elapsed = time.time() - last_activity
            if elapsed > 60:  # Every minute, log progress
                log(f"Build still running... ({int(elapsed/60)} minutes elapsed)", "PROGRESS")
                last_activity = time.time()
                idle_count = 0
        
        # Get output
        build_out, build_err = build_proc.communicate()
        build_ret = build_proc.returncode
        
        log(f"Build exit code: {build_ret}")
        
        if build_ret == 0:
            output_dir = Path("/home/lrvick/Sources/stagex/out") / f"{package_target.replace('-', '_')}"
            if output_dir.exists():
                log(f"  Build successful!")
                return True
            else:
                log(f"  Build completed but output not found", "WARNING")
                return False
        else:
            log(f"  Build failed: {build_err}", "ERROR")
            return False
    
    except Exception as e:
        log(f"  Build error: {e}", "ERROR")
        return False


def read_current_version_from_toml(package_path: Path) -> Optional[str]:
    """Read current version from package.toml."""
    toml_file = package_path / "package.toml"
    
    if not toml_file.exists():
        return None
    
    content = toml_file.read_text()
    version_match = re.search(r'^version\s*=\s*["\']([^"\']+)["\']', content, re.MULTILINE)
    return version_match.group(1) if version_match else None


def find_package_in_tree(package_name: str) -> Tuple[Optional[Path], Optional[str]]:
    """Find a package in the Stagex tree."""
    for category in ["bootstrap", "core", "pallet", "user"]:
        category_dir = Path("/home/lrvick/Sources/stagex/packages") / category
        if not category_dir.exists():
            continue
        
        package_dirs = sorted([d for d in category_dir.iterdir() if d.is_dir()])
        
        for pkg_dir in package_dirs:
            if pkg_dir.name == package_name:
                return pkg_dir, category
        
        # Try matching without category prefix
        for pkg_dir in package_dirs:
            if pkg_dir.name == package_name:
                return pkg_dir, category
    
    return None, None


def main():
    """Main entry point."""
    log("=" * 80)
    log("StageX Package Update Automation")
    log("=" * 80)
    
    log("\n1. Computing build order from make dry-run...")
    packages_in_order = get_build_order()
    if packages_in_order:
        log(f"  Found {len(packages_in_order)} packages in build order")
    else:
        log("  No packages found in build order", "ERROR")
        sys.exit(1)
    
    log("\n2. Fetching release-monitoring.org data...")
    projects = get_release_monitoring_data()
    
    # Process each package in build order
    log("\n3. Processing packages in build order...")
    log("=" * 80)
    
    successful_updates = []
    failed_updates = []
    
    for package_full in packages_in_order:
        # Extract package name from full target (e.g., "user-vim" -> "vim")
        package_name = package_full.split('-', 1)[-1] if '-' in package_full else package_full
        package_category = package_full.split('-', 1)[0] if '-' in package_full else "core"
        
        log(f"\n{'=' * 80}")
        log(f"Processing: {package_name} (target: {package_full})")
        log(f"{'=' * 80}")
        
        # Find the package in the tree
        package_path, category = find_package_in_tree(package_name)
        
        if not package_path:
            log(f"  Package not found in tree", "WARNING")
            failed_updates.append((package_name, "Package not found"))
            continue
        
        # Read current version
        current_version = read_current_version_from_toml(package_path)
        if not current_version:
            log(f"  Could not determine current version", "WARNING")
            continue
        
        log(f"  Current version: {current_version}")
        
        # Check release-monitoring for updates
        project = find_package_in_monitoring(package_name, projects)
        
        if not project:
            log(f"  Package not found in release-monitoring.org", "WARNING")
            continue
        
        latest_version = get_latest_version_from_package(project, current_version)
        
        if not latest_version:
            log(f"  No update available (current: {current_version})")
            continue
        
        log(f"  Update available: {latest_version}")
        
        # Get download URL
        download_url = get_download_url_from_package(project, latest_version)
        
        if not download_url:
            log(f"  Could not determine download URL", "WARNING")
            failed_updates.append((package_name, "No download URL"))
            continue
        
        log(f"  Download URL: {download_url}")
        
        # Download archive
        archive_path = Path("/tmp") / f"{package_name}-{latest_version}.tar.gz"
        
        if not download_archive(download_url, archive_path):
            log(f"  Download failed", "ERROR")
            failed_updates.append((package_name, "Download failed"))
            continue
        
        # Compute SHA256
        log(f"  Computing SHA256...")
        sha256 = compute_sha256(archive_path)
        log(f"  SHA256: {sha256}")
        
        # Update package.toml
        log(f"  Updating package.toml...")
        if not update_package_toml(package_path, latest_version, sha256):
            log(f"  Failed to update package.toml", "ERROR")
            failed_updates.append((package_name, "Failed to update package.toml"))
            continue
        
        # Build the package
        log(f"  Building {package_full}...")
        if not build_package(package_full):
            log(f"  Build failed", "ERROR")
            failed_updates.append((package_name, "Build failed"))
            continue
        
        log(f"  Update successful!")
        successful_updates.append((package_name, current_version, latest_version))
        
        # Clean up archive
        if archive_path.exists():
            archive_path.unlink()
    
    # Final summary
    log("\n" + "=" * 80)
    log("FINAL SUMMARY")
    log("=" * 80)
    
    log(f"\nSuccessful updates: {len(successful_updates)}")
    for pkg, old_ver, new_ver in successful_updates:
        log(f"  - {pkg}: {old_ver} -> {new_ver}")
    
    log(f"\nFailed updates: {len(failed_updates)}")
    for pkg, reason in failed_updates:
        log(f"  - {pkg}: {reason}")
    
    log("\n" + "=" * 80)


if __name__ == "__main__":
    main()
