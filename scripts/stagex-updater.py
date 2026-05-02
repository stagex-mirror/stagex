#!/usr/bin/env python3
"""
Stagex Package Updater Script

This script automates version updates for packages in the Stagex distribution:
1. Determines build order from make dry-run output
2. For each package in order:
   - Checks if it's up-to-date via release-monitoring.org API
   - If out of date, downloads latest source and updates package.toml
   - Attempts to build
   - On success: commits and pushes to configurable branch
   - On failure: logs to file for later investigation

Usage:
    python3 scripts/stagex-updater.py --help
    python3 scripts/stagex-updater.py --dry-run
    python3 scripts/stagex-updater.py --single gcc
    python3 scripts/stagex-updater.py --all
"""

import argparse
import csv
import hashlib
import http.client
import json
import logging
import os
import re
import shutil
import subprocess
import sys
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Optional
from urllib.parse import quote, urljoin
import urllib.request
import urllib.error


# ────────────────────────────────────────────────────────────────────
# Configuration
# ────────────────────────────────────────────────────────────────────

STAGEX_ROOT = Path(__file__).resolve().parent.parent
LOG_FILE = STAGEX_ROOT / "scripts" / "updater.log"
BACKUP_DIR = STAGEX_ROOT / "scripts" / "backups"
BRANCH_NAME = "lance/megabump"  # Default branch name


# ────────────────────────────────────────────────────────────────────
# Logging Setup
# ────────────────────────────────────────────────────────────────────

def setup_logging():
    """Configure logging to file and console."""
    log_dir = LOG_FILE.parent
    log_dir.mkdir(parents=True, exist_ok=True)
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(LOG_FILE),
            logging.StreamHandler()
        ]
    )
    return logging.getLogger(__name__)


# ────────────────────────────────────────────────────────────────────
# Data Classes
# ────────────────────────────────────────────────────────────────────

@dataclass
class PackageInfo:
    """Information about a single package."""
    name: str
    stage: str  # bootstrap, core, pallet, user
    release_monitoring_id: Optional[int]
    current_version: str
    toml_path: Path
    containerfile_path: Path
    fetch_dir: Optional[Path] = None


@dataclass
class BuildOrderItem:
    """Single item in build order."""
    stage: str
    name: str
    deps: list


# ────────────────────────────────────────────────────────────────────
# Build Order Detection
# ────────────────────────────────────────────────────────────────────

def get_build_order() -> list:
    """
    Determine build order by inspecting make -n output.
    
    Returns a topologically sorted list of packages respecting dependencies.
    """
    logger = logging.getLogger(__name__)
    logger.info("Determining build order from make -n...")
    
    # Run make -n to get build order
    try:
        result = subprocess.run(
            ['make', '-n'],
            cwd=STAGEX_ROOT,
            capture_output=True,
            text=True,
            timeout=60
        )
        output = result.stdout + result.stderr
    except Exception as e:
        logger.warning(f"make -n failed: {e}")
        # Fallback: parse targets.mk if it exists
        targets_file = STAGEX_ROOT / "out" / "targets.mk"
        if targets_file.exists():
            output = targets_file.read_text()
        else:
            logger.error("Could not determine build order")
            return []
    
    # Parse output to extract package dependencies
    order = []
    seen = set()
    
    # Look for patterns like "tar -C out/core-expat -mx"
    pattern = re.compile(r'tar -C (out/(\w+)-(\w+))')
    for match in pattern.finditer(output):
        full_path = match.group(1)
        stage = match.group(2)
        name = match.group(3)
        key = f"{stage}-{name}"
        if key not in seen:
            seen.add(key)
            order.append(BuildOrderItem(stage=stage, name=name, deps=[]))
    
    logger.info(f"Found {len(order)} packages in build order")
    return order


# ────────────────────────────────────────────────────────────────────
# Release Monitoring.org API
# ────────────────────────────────────────────────────────────────────

def query_rm_org(pid: int, pname: str) -> tuple:
    """
    Query release-monitoring.org for latest version info using Anitya API v2.
    
    Returns (latest_version, raw_data) or (None, {}) if not found.
    """
    logger = logging.getLogger(__name__)
    
    # Use the proper JSON API v2 endpoint - search by name only
    api_url = f'https://release-monitoring.org/api/v2/projects/?name={quote(pname)}'
    
    try:
        req = urllib.request.Request(
            api_url,
            headers={
                'User-Agent': 'stagex-updater/1.0',
                'Accept': 'application/json',
            }
        )
        
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            
        # Check if we found the project (API returns 'items' not 'projects')
        if not data.get('items'):
            logger.warning(f"Project {pname} not found in release-monitoring.org")
            return None, {}
            
        # Find the matching project by ID
        project = None
        for p in data['items']:
            if p.get('id') == pid:
                project = p
                break
        
        if not project:
            # If ID doesn't match, use the first result (likely the right project)
            project = data['items'][0]
            logger.warning(f"Project ID mismatch for {pname}, using first result")
        
        # Extract latest version
        latest_version = project.get('version')
        
        if not latest_version:
            logger.warning(f"No version found for {pname}")
            return None, {}
            
        return latest_version, project
        
    except urllib.error.HTTPError as e:
        logger.warning(f"HTTP {e.code} for API query {pname}: {e.reason}")
        return None, {}
    except Exception as e:
        logger.warning(f"API query failed for {pname}: {e}")
        return None, {}


def get_download_url(version: str, mirrors: list) -> Optional[str]:
    """
    Get download URL from mirrors list.
    
    Returns the first working URL or None.
    """
    for mirror in mirrors:
        url = mirror.replace('{version}', version)
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'stagex-updater/1.0'})
            resp = urllib.request.urlopen(req, timeout=15)
            if resp.status == 200:
                return resp.geturl()
        except:
            pass
    return None


# ────────────────────────────────────────────────────────────────────
# Package Management
# ────────────────────────────────────────────────────────────────────

def load_packages() -> dict:
    """Load all package metadata from package.toml files."""
    logger = logging.getLogger(__name__)
    packages = {}
    
    csv_path = STAGEX_ROOT / 'config_release_monitoring.csv'
    csv_data = {}
    if csv_path.exists():
        with csv_path.open(mode='r', newline='') as f:
            reader = csv.DictReader(f)
            for row in reader:
                csv_data[row['name'].strip().lower()] = int(row['id'].strip())
    
    for pth in STAGEX_ROOT.glob('packages/**/package.toml'):
        rel = pth.relative_to(STAGEX_ROOT / 'packages')
        stage, name = rel.parts[0], rel.parts[1]
        pkg_name = name.lower()
        
        try:
            with pth.open('rb') as f:
                data = tomllib.load(f)
            
            version = data['package']['version']
            rm_id = csv_data.get(pkg_name)
            
            # Find containerfile
            containerfile = pth.parent / 'Containerfile'
            fetch_dir = pth.parent / 'fetch' if pth.parent.joinpath('fetch').is_dir() else None
            
            packages[pkg_name] = PackageInfo(
                name=pkg_name,
                stage=stage,
                release_monitoring_id=rm_id,
                current_version=version,
                toml_path=pth,
                containerfile_path=containerfile,
                fetch_dir=fetch_dir
            )
        except Exception as e:
            logger.warning(f"Failed to load {pkg_name}: {e}")
    
    logger.info(f"Loaded {len(packages)} packages")
    return packages


def download_source(version: str, mirrors: list, dest_dir: Path) -> tuple:
    """
    Download source tarball and calculate hash.
    
    Returns (success, hash, dest_file).
    """
    logger = logging.getLogger(__name__)
    
    # Get download URL
    url = get_download_url(version, mirrors)
    if not url:
        logger.error(f"No working download URL found for version {version}")
        return False, None, None
    
    # Download file
    dest_file = dest_dir / f"source-{version}.tar.gz"
    try:
        logger.info(f"Downloading from {url}")
        urllib.request.urlretrieve(url, dest_file)
        
        # Calculate SHA256
        sha256 = hashlib.sha256()
        with dest_file.open('rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                sha256.update(chunk)
        
        hash_value = sha256.hexdigest()
        logger.info(f"Downloaded {dest_file.name} (SHA256: {hash_value})")
        return True, hash_value, dest_file
        
    except Exception as e:
        logger.error(f"Download failed: {e}")
        if dest_file.exists():
            dest_file.unlink()
        return False, None, None


def update_package_toml(pkg: PackageInfo, new_version: str, new_hash: str) -> bool:
    """
    Update package.toml with new version and hash.
    
    Returns True on success.
    """
    logger = logging.getLogger(__name__)
    
    try:
        toml_path = pkg.toml_path
        content = toml_path.read_text()
        
        # Update version
        content = re.sub(
            r'version\s*=\s*"[^"]*"',
            f'version = "{new_version}"',
            content,
            count=1
        )
        
        # Update hash
        content = re.sub(
            r'hash\s*=\s*"[^"]+"',
            f'hash = "{new_hash}"',
            content,
            count=1
        )
        
        toml_path.write_text(content)
        logger.info(f"Updated {pkg.name} to {new_version}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to update {pkg.name}: {e}")
        return False


def backup_package(pkg: PackageInfo) -> Path:
    """Create backup of package before changes."""
    logger = logging.getLogger(__name__)
    backup_dir = BACKUP_DIR / pkg.stage / pkg.name
    backup_dir.mkdir(parents=True, exist_ok=True)
    
    # Copy toml and containerfile
    if pkg.toml_path.exists():
        shutil.copy(pkg.toml_path, backup_dir / 'package.toml')
    if pkg.containerfile_path.exists():
        shutil.copy(pkg.containerfile_path, backup_dir / 'Containerfile')
    
    logger.info(f"Backed up {pkg.name} to {backup_dir}")
    return backup_dir


# ────────────────────────────────────────────────────────────────────
# Build Process
# ────────────────────────────────────────────────────────────────────

def build_package(pkg: PackageInfo) -> tuple:
    """
    Attempt to build a package.
    
    Returns (success, output_or_error).
    """
    logger = logging.getLogger(__name__)
    
    try:
        result = subprocess.run(
            ['make', f'{pkg.stage}-{pkg.name}'],
            cwd=STAGEX_ROOT,
            capture_output=True,
            text=True,
            timeout=600  # 10 minutes
        )
        
        success = result.returncode == 0
        output = result.stdout + result.stderr
        
        logger.info(f"Build {'succeeded' if success else 'failed'} for {pkg.name}")
        return success, output
        
    except subprocess.TimeoutExpired:
        logger.error(f"Build timeout for {pkg.name}")
        return False, "Build timed out after 10 minutes"
    except Exception as e:
        logger.error(f"Build error for {pkg.name}: {e}")
        return False, str(e)


def commit_and_push(pkg: PackageInfo, message: str) -> bool:
    """
    Commit and push changes to the branch.
    
    Returns True on success.
    """
    logger = logging.getLogger(__name__)
    
    try:
        # Stage changes
        subprocess.run(
            ['git', 'add', '-A'],
            cwd=STAGEX_ROOT,
            check=True
        )
        
        # Commit with message
        subprocess.run(
            ['git', 'commit', '-m', f'Update {pkg.name} to {pkg.current_version}'],
            cwd=STAGEX_ROOT,
            check=True
        )
        
        logger.info(f"Committed changes for {pkg.name}")
        return True
        
    except subprocess.CalledProcessError as e:
        logger.error(f"Commit failed for {pkg.name}: {e}")
        return False


def push_to_remote(branch: str) -> bool:
    """Push current branch to remote."""
    logger = logging.getLogger(__name__)
    
    try:
        subprocess.run(
            ['git', 'push', 'origin', branch],
            cwd=STAGEX_ROOT,
            check=True,
            capture_output=True
        )
        logger.info(f"Pushed to {branch}")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Push failed: {e}")
        return False


# ────────────────────────────────────────────────────────────────────
# Main Update Process
# ────────────────────────────────────────────────────────────────────

def update_single_package(pkg_name: str, dry_run: bool = False) -> bool:
    """
    Update a single package.
    
    Returns True if successful.
    """
    logger = logging.getLogger(__name__)
    packages = load_packages()
    
    if pkg_name not in packages:
        logger.error(f"Package {pkg_name} not found")
        return False
    
    pkg = packages[pkg_name]
    
    if not pkg.release_monitoring_id:
        logger.warning(f"{pkg_name} has no RM.org ID, skipping")
        return False
    
    # Query RM.org
    latest_version, _ = query_rm_org(pkg.release_monitoring_id, pkg.name)
    
    if not latest_version:
        logger.warning(f"Could not determine latest version for {pkg_name}")
        return False
    
    logger.info(f"Current: {pkg.current_version}, Latest: {latest_version}")
    
    if latest_version == pkg.current_version:
        logger.info(f"{pkg_name} is up to date")
        return True
    
    # Download and update
    logger.info(f"Updating {pkg_name} to {latest_version}")
    
    if dry_run:
        logger.info(f"[DRY-RUN] Would update {pkg_name} to {latest_version}")
        return True
    
    # Backup and update
    backup_package(pkg)
    
    # Get package.toml to extract mirrors
    with pkg.toml_path.open('rb') as f:
        data = tomllib.load(f)
    
    sources = data.get('sources', {})
    source_name = pkg.name  # Usually matches package name
    if source_name not in sources:
        source_name = list(sources.keys())[0]
    
    mirrors = sources[source_name].get('mirrors', [])
    
    # Download source
    success, new_hash, dest_file = download_source(latest_version, mirrors, STAGEX_ROOT / 'fetch')
    
    if not success:
        logger.error(f"Failed to download source for {pkg_name}")
        return False
    
    # Update package.toml
    success = update_package_toml(pkg, latest_version, new_hash)
    
    if success:
        success, build_output = build_package(pkg)
        
        if success:
            commit_and_push(pkg, f"Update {pkg.name} to {latest_version}")
            return True
        else:
            logger.error(f"Build failed for {pkg.name}:\n{build_output}")
            return False
    
    return False


def update_all_packages(dry_run: bool = False, branch: str = BRANCH_NAME) -> int:
    """
    Update all packages in build order.
    
    Returns count of successful updates.
    """
    logger = logging.getLogger(__name__)
    
    # Get build order
    order = get_build_order()
    packages = load_packages()
    
    success_count = 0
    
    for item in order:
        pkg_name = item.name
        logger.info(f"Processing {pkg_name}...")
        
        if pkg_name in packages:
            if update_single_package(pkg_name, dry_run):
                success_count += 1
    
    # Push all changes
    if not dry_run and success_count > 0:
        push_to_remote(branch)
    
    return success_count


# ────────────────────────────────────────────────────────────────────
# CLI Interface
# ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='Stagex Package Updater')
    parser.add_argument('--single', type=str, help='Update single package by name')
    parser.add_argument('--all', action='store_true', help='Update all packages')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done')
    parser.add_argument('--branch', type=str, default=BRANCH_NAME, help='Branch to push to')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose output')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    setup_logging()
    logger = logging.getLogger(__name__)
    
    if args.single:
        success = update_single_package(args.single, args.dry_run)
        sys.exit(0 if success else 1)
    elif args.all:
        count = update_all_packages(args.dry_run, args.branch)
        logger.info(f"Updated {count} packages")
        sys.exit(0)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()
