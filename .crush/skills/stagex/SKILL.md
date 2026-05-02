---
name: stagex
description: Use when working with Stagex Linux package creation - creating package.toml, Containerfiles, building packages, verifying reproducibility, or creating pull requests for new packages.
---

# Stagex Package Creation Skill

This skill provides a comprehensive workflow for creating new packages in the Stagex Linux distribution.

## Overview

Creating a package for Stagex involves:
1. Creating a feature branch from staging
2. Adding package files (package.toml and Containerfile)
3. Building the package with all dependencies
4. Verifying reproducibility with a clean rebuild
5. Creating a pull request targeting staging

## Prerequisites

- Git configured with your credentials
- Docker or compatible container runtime
- Access to the Stagex repository
- Source tarballs available (either in fetch/ directory or with accessible mirrors)

For reference implementations, consult existing Stagex packages using the same build systems or languages:
- Check `packages/user/` and `packages/core/` for similar Rust/C/C++ packages
- When packaging tools already in Stagex, reference their package.toml and Containerfile patterns

## Workflow

### 1. Check for Existing PRs

Before creating a new package, check if someone else is already working on it:

```bash
# List open PRs on Codeberg
fj --host codeberg.org pr list --state open --base staging

# Search for PRs containing the package name
# Look for titles like "WIP: Add $package_name" or similar
```

If a PR already exists for the package:
- Comment on the existing PR to coordinate
- Do NOT create a duplicate package

If no PR exists, proceed with creating the package.

### 2. Create Branch from Staging

```bash
# Fetch latest staging branch
git fetch origin staging

# Create new branch following naming convention
git checkout -b $package_name origin/staging
```

**CRITICAL BRANCH RULE**: Always create and push branches named `$package_name`. Never push directly to `staging` or any branch not named `$package_name`. The workflow is:
1. Create branch `$package_name` from `origin/staging`
2. Commit all changes on the `$package_name` branch
3. Push `$package_name` to the `personal` fork
4. Create PR targeting `origin/staging` from `$package_name`

This prevents accidental direct pushes to staging and ensures all changes go through PR review.

**CRITICAL PR BASE RULE**: Always target `staging` for PRs — **never** `main`. Use `fj pr create --repo stagex/stagex --base staging --agit` which correctly resolves to `origin/staging`. Always double-check: PR base must be `staging`, not `main`.

**CRITICAL CACHE RULE**: When clearing cache for reproducible builds, clear cache ONLY for the bits we add or modify. Never clear global package cache or docker cache. Always use targeted cache clearing (e.g., `rm -rf out/user-$package_name/`) instead of global cache flushes (`make clean-all`, `docker system prune`, etc.). The goal is reproducible builds, not cache destruction — only remove what's needed for the specific package being built.

### 3. Implement Package Changes

Create all package files (package.toml, Containerfile, etc.) in the package directory:

```bash
mkdir -p packages/user/$package_name/fetch
cd packages/user/$package_name
```

Add all package files, then commit as a **single commit** with a comprehensive message:

```bash
git add packages/user/$package_name/

git commit -m "Add $package_name ($version)

$brief_description

Key features:
- Uses system dependencies from $dependency1, $dependency2
- Follows Stagex CMake conventions
- Supports reproducible builds

Build verified:
- [x] Initial build successful
- [x] Reproducibility verified
- [x] License installed correctly
"
```

### 4. Build Package (First Build)

```bash
mkdir -p packages/user/$package_name/fetch
cd packages/user/$package_name
```

**Cache Rule**: Do NOT clear global cache. Only remove the specific output directory for this package if needed. Never run `docker system prune` or `make clean-all` unless explicitly targeting this package.

### 5. Verify Reproducibility (Second Build from Cache)

```bash
# Clean build artifacts
make clean-user-$package_name

# Second build without cache (proves deterministic build)
make PROGRESS=plain user-$package_name

# Compare outputs (should be identical)
sha256sum out/user-$package_name/*.tar.gz
```

**Cache Rule**: When verifying reproducibility, only delete the output directory for the package being tested:
```bash
rm -rf out/user-$package_name/
```

Never clear global docker cache or package cache unless specifically modifying that package. The rule: clear cache ONLY for bits we add or modify.

### 6. Test the Package

Create package.toml and Containerfile before building.

### 7. Commit Changes

```bash
# Add package files
git add packages/user/$package_name/

# Commit with descriptive message (single commit)
git commit -m "Add $package_name ($version)

$brief_description

Key features:
- Uses system dependencies from $dependency1, $dependency2
- Follows Stagex CMake conventions
- Supports reproducible builds

Build verified:
- [x] Initial build successful
- [x] Reproducibility verified
- [x] License installed correctly
"
```

### 8. Push and Create PR

```toml
[package]
name = "$package_name"
version = "$version"
description = "$brief_description"
license = "$spdx_license_expression"
website = "$project_url"

[sources.$source_name]
hash = "$sha256_hash"
format = "tar.gz"
file = "$filename.{format}"
mirrors = ["file://fetch/{file}", "https://example.com/path/to/{file}"]
```

**Key Fields**:
- `name`: Package name (lowercase, hyphens for multi-word)
- `version`: Exact version string
- `license`: SPDX expression (e.g., "MIT", "Apache-2.0 OR MIT", "GPL-3.0-or-later")
- `hash`: SHA256 hash of the source tarball
- `mirrors`: List of download mirrors (local first, then remote)

**Hash Verification**:
```bash
sha256sum fetch/$package_name-$version.tar.gz
```

### 4. Create Containerfile

The `Containerfile` defines the build process:

```dockerfile
FROM stagex/pallet-$pallet_name AS build
ARG VERSION
COPY --from=stagex/$dependency1 / /
COPY --from=stagex/$dependency2 / /
ADD fetch/$source_file.tar.gz .
WORKDIR /$package_name-${VERSION}
RUN <<-EOF
	# Build commands
	cmake \
		-B build \
		-G Ninja \
		-Wno-dev \
		-DCMAKE_INSTALL_PREFIX=/usr \
		-DCMAKE_INSTALL_LIBDIR=lib
	cmake --build build -j "$(nproc)"
	DESTDIR="/rootfs" cmake --install build --prefix /usr
	# Install license
	install -Dm644 LICENSE /rootfs/usr/share/licenses/$package_name/LICENSE
EOF
FROM stagex/core-filesystem AS package
COPY --from=build /rootfs/ /
```

**Pallet Selection**:
- `gcc-cmake-busybox`: For C/C++ projects using CMake
- `clang-cmake-busybox`: For projects preferring Clang
- `gcc-meson-busybox`: For Meson build systems
- `luarocks`: For Lua/LuaJIT packages
- `python`: For Python packages

**Dependency Management**:
- List all runtime dependencies with `COPY --from=stagex/...`
- System libraries should be from `core-*` or `user-*` packages
- Build tools come from the pallet

**Build Best Practices**:
- Use `DESTDIR="/rootfs"` for installation
- Always install licenses to `/usr/share/licenses/$package_name/`
- Set `CMAKE_INSTALL_LIBDIR=lib` to avoid lib64 issues
- Use `-Wno-dev` to suppress developer warnings
- Use heredoc syntax `RUN <<-EOF` for multi-line commands

### 5. Build the Package

```bash
# Build package (first build with cache)
make user-$package_name

# Verify build succeeded
ls -la out/user-$package_name/
```

**Build Commands**:
- `make user-$package_name`: Build the package
- `make PROGRESS=plain user-$package_name`: Plain output for debugging
- `make clean-user-$package_name`: Clean build artifacts

### 6. Verify Reproducibility

```bash
# Clean build artifacts
make clean-user-$package_name

# Second build without cache (proves deterministic build)
make PROGRESS=plain user-$package_name

# Compare outputs (should be identical)
sha256sum out/user-$package_name/*.tar.gz
```

**Reproducibility Requirements**:
- Build must succeed without modifications
- Output hash must match between builds
- No non-reproducible elements (timestamps, build paths, etc.)

**Cache Rule**: For the clean rebuild, only remove the specific package output:
```bash
rm -rf out/user-$package_name/
```

Never clear global docker cache or package cache unless specifically modifying that package.

**Pushing**: Push the feature branch to the **personal** fork (NOT `origin`):
```bash
git push personal $package_name:$package_name
```

Push to `$package_name:$package_name` to create a separate branch on the fork (not merged into `staging`). `origin` is the upstream repo (`stagex/stagex`) and pushing `$package_name` to `origin` can fast-forward `staging` (if the branch tracks `origin/staging`). Always push to `personal` — the fork remote (`lrvick/stagex`). Configure `personal` with the API token URL if needed: `git remote set-url personal 'https://TOKEN@codeberg.org/lrvick/stagex.git'`.

**PR Creation**: For PRs targeting `origin/staging` (upstream repo), use `fj pr create "WIP: Add $package_name ($version)" --repo stagex/stagex --base staging --agit`. This is the **only** pattern that creates PRs targeting `origin/staging` correctly. The `--agit` workflow on the upstream repo with explicit `--base staging` resolves to `origin/staging`.

For PRs on the personal fork (test PRs), use `fj pr create --repo lrvick/stagex --base staging --head $package_name`.

### 7. Test the Package

```bash
# Extract and inspect
tar -tf out/user-$package_name/blobs/sha256/* | grep -E "usr/bin|usr/lib" | head -20

# Run if executable exists (adjust for your package)
docker run --rm out/user-$package_name --version
```

### 8. Clean Build Verification (Second Build Without Cache)

```bash
# Record current digests from index.json before removing artifacts
cat out/user-$package_name/index.json > /tmp/first-build-index.json

# Delete ONLY the artifacts for packages touched in this branch
rm -rf out/user-$package_name/

# Second build without ANY cache (NOCACHE=1 forces complete rebuild)
make NOCACHE=1 user-$package_name

# Compare digests to verify reproducibility
cat out/user-$package_name/index.json
diff /tmp/first-build-index.json out/user-$package_name/index.json
```

**Cache Rule**: For the NOCACHE rebuild, only remove the specific package output:
```bash
rm -rf out/user-$package_name/
```

Never clear global docker cache or package cache unless specifically modifying that package. The rule: clear cache ONLY for bits we add or modify.

### 9. Commit Changes

```bash
# Add package files
git add packages/user/$package_name/

# Commit with descriptive message (single commit for all changes)
git commit -m "Add $package_name ($version)

$brief_description

Key features:
- Uses system dependencies from $dependency1, $dependency2
- Follows Stagex CMake conventions
- Supports reproducible builds

Build verified:
- [x] Initial build successful
- [x] Reproducibility verified (without cache)
- [x] License installed correctly
"
```

### 10. Push and Create PR

```bash
# Push branch to PERSONAL fork (NOT origin!)
# Push to $package_name:$package_name to create a separate branch on the fork
git push personal $package_name:$package_name

# Create PR targeting origin/staging using fj tool
fj --host codeberg.org pr create "WIP: Add $package_name ($version)" \
  --repo stagex/stagex \
  --base staging \
  --agit \
  --body "## Summary

- Added $package_name $version package
- Uses system dependencies: $dep1, $dep2
- Follows Stagex packaging conventions

## Build Information

- Total clean compilation time: $BUILD_TIME
- CPU model: $CPU_MODEL
- Expected digests:
  - Package: $PACKAGE_HASH
  - Source: $SOURCE_HASH

## Packages Added

- user/$package_name ($version)

## Test Plan

- [ ] Build: \`make user-$package_name\`
- [ ] Reproducibility: clean rebuild
- [ ] Runtime: verify binary executes
"
```

## Common Dependency Patterns

### C/C++ Projects with CMake
```dockerfile
FROM stagex/pallet-gcc-cmake-busybox AS build
COPY --from=stagex/core-make / /
COPY --from=stagex/user-libuv / /
COPY --from=stagex/user-openssl / /
```

### Lua/LuaJIT Projects
```dockerfile
FROM stagex/pallet-gcc-cmake-busybox AS build
COPY --from=stagex/user-luajit / /
COPY --from=stagex/user-libuv / /
```

### Tree-sitter Grammars
```dockerfile
FROM stagex/pallet-gcc-busybox AS build
ARG VERSION
ADD fetch/$parser_name-${VERSION}.tar.gz .
WORKDIR /$parser_name-${VERSION}
RUN <<-EOF
	# Build parser directly (no tree-sitter CLI needed)
	mkdir -p build
	cd build
	cmake \
		-G Ninja \
		-DCMAKE_INSTALL_PREFIX=/usr \
		..
	cmake --build .
	DESTDIR="/rootfs" cmake --install .
	install -Dm644 ../LICENSE /rootfs/usr/share/licenses/$parser_name/LICENSE
EOF
```

## Troubleshooting

### Hash Mismatch
```bash
# Update hash in package.toml
sha256sum fetch/$file.tar.gz
# Update the hash value in [sources] section
```

### Missing Dependencies
```bash
# Check available packages
ls packages/core/ packages/user/

# Add missing dependency to Containerfile
COPY --from=stagex/user-$missing_dep / /
```

### CMake lib64 Issues
```bash
# Add to cmake configuration
-DCMAKE_INSTALL_LIBDIR=lib
```

### Build Fails on First Try
```bash
# Check build logs
make PROGRESS=plain user-$package_name 2>&1 | tail -50

# Common fixes:
# - Add missing dependencies
# - Fix CMake options
# - Ensure proper tarball structure
```

## Package Checklist

Before submitting PR:

- [ ] Package name follows conventions (lowercase, hyphens)
- [ ] Version string is accurate
- [ ] License is SPDX expression
- [ ] SHA256 hash is verified
- [ ] All dependencies are declared
- [ ] Build succeeds on first attempt
- [ ] Reproducibility verified (clean rebuild without cache)
- [ ] License file installed correctly
- [ ] Binary runs and shows version
- [ ] PR title prefixed with "WIP: "
- [ ] PR targets `staging` branch (not `main`!)
- [ ] PR includes build info (time, CPU, digests)
- [ ] Branch name is `$package_name` (not `lance/$package_name`)
- [ ] Cache cleared only for modified bits (no global cache flush)
- [ ] PR created via `fj pr create --repo stagex/stagex --base staging --agit`
- [ ] Branch pushed to `personal` as `$package_name:$package_name`
- [ ] Push to `personal` remote, NOT `origin` (pushing `$package_name` to `origin` can fast-forward `staging`)

## Related Documentation

- [Stagex Repository](https://codeberg.org/stagex/stagex)
- [Existing Packages](https://codeberg.org/stagex/stagex/tree/branch/main/packages/user)
- [Core Packages](https://codeberg.org/stagex/stagex/tree/branch/main/packages/core)
- [Pallets](https://codeberg.org/stagex/stagex/tree/branch/main/packages/pallet)

## Notes

- Always build from staging branch
- Use system dependencies instead of bundled ones
- Follow existing package patterns
- Test reproducibility before creating PR
- Mark PR as WIP until fully tested
- Branch naming: `$package_name` (not `lance/$package_name`)
- Cache clearing: only clear cache for bits we add or modify, never global cache
- PR base: always target `staging`, never `main` — the --agit workflow auto-detects from HEAD which may be `main`
- Push: `git push personal $package_name:$package_name` (NOT `origin` — pushing `$package_name` to `origin` fast-forwards `staging`)
- PR: use `fj pr create --repo stagex/stagex --base staging --agit` — targets `origin/staging` correctly
- If PR created by `--agit` targets `main`, use `fj pr browse` to open the web and manually change base to `staging`
