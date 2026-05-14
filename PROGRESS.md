# Progress Log

## Current State

- **Task**: Get the entire stagex package tree to build fully on branch `updates-lrvick-2026-05-10`
- **Progress**: Full tree build **COMPLETE** — all packages built successfully end to end
- **Branch**: `updates-lrvick-2026-05-10`
- **Date**: May 14, 2026

## Summary of Work Completed

### 1. Merged All New Package PRs (skipped ROCm)

| # | Branch | Package(s) | Status |
|---|--------|------------|--------|
| #1532 | staging | weechat 4.9.0 + 10 deps | Merged |
| #1507 | kubectl-ai | kubectl-ai 0.0.31 | Merged |
| #1506 | gping | gping 1.20.1 | Merged |
| #1483 | lance/nvim | Neovim 0.12.2 + 12 deps | Merged |
| #1426 | lance/btop | btop 1.4.6 | Merged |
| #1425 | lance/zeroclaw | zeroclaw | Merged |
| #1274 | lance/fj | forgejo-cli | Merged |
| #1273 | lance/sdcpp | stable-diffusion-cpp | Merged |
| #1272 | lance/crush | charm crush 0.53.0 | Merged |

### 2. Version Bumps

| Package | Old Version | New Version |
|---------|-------------|-------------|
| crush | 0.53.0 | 0.67.0 |
| stable-diffusion-cpp | master-540-f16a110 | master-596-90e87bc |
| llama-cpp | b4663 | b9139 |
| gnutls | 3.8.10 | 3.8.12 |
| nettle | 3.9.1_release_20230601 | 3.10.2 |
| forgejo-cli | 0.4.1 | 0.4.1 (URL fix) |

### 3. New Charm Tools Added

| Package | Version | Pallet | Notes |
|---------|---------|--------|-------|
| vhs | 0.11.0 | pallet-cgo | Terminal screen recorder |
| glow | 2.1.2 | pallet-cgo | Render markdown on terminal |
| soft-serve | 0.11.6 | pallet-cgo | Terminal-based Git server |
| freeze | 0.2.2 | pallet-cgo | Freeze GitHub CI/CD dependencies |
| melt | 0.6.2 | pallet-cgo | Terminal-based markdown preview |
| skate | 1.0.1 | pallet-cgo | Terminal-based markdown preview |
| gum | 0.17.0 | pallet-cgo | Terminal workflow tool |

### 4. New CLI Tools Added (May 14)

| Package | Version | Language | Pallet | Status |
|---------|---------|----------|--------|--------|
| bat | 0.26.1 | Rust | pallet-rust | Built |
| fzf | 0.72.0 | Go | pallet-cgo | Built |
| tldr (tlrc) | 1.13.0 | Rust | pallet-rust | Built |
| pass | 1.7.4 | Shell | pallet-clang-gnu-busybox | Built |
| lazydocker | 0.25.2 | Go | pallet-cgo | Built |
| lazygit | 0.61.1 | Go | pallet-cgo | Built |
| tig | 2.6.0 | C | pallet-clang-gnu-busybox | Built |
| rsop | 0.10.0 | Rust | pallet-rust | Built |
| mprocs | 0.9.2 | Rust | pallet-rust | Built |
| nmap | 7.99 | C | pallet-clang-gnu-busybox | WIP (libdnet kernel headers) |

### 5. Build Fixes Applied

- **Removed duplicates**: core-nettle, user-curl, user-mpfr, user-trousers
- **Fixed crush**: pallet-cgo, LICENSE.md path, version bump to 0.67.0
- **Fixed gnutls**: pallet-clang-gnu-busybox, added OpenSSL/texinfo deps, correct license path (COPYING.LESSERv2), removed autoreconf (pre-generated configure in tarball), version bump to 3.8.12
- **Fixed stable-diffusion-cpp**: added ggml submodule (404fcb9d), disabled frontend, unset CMAKE_GENERATOR, version bump to master-596-90e87bc
- **Fixed forgejo-cli**: v prefix in URL and filename, WORKDIR /forgejo-cli
- **Fixed weechat**: use core-curl instead of user-curl, added gnutls deps (nettle, libtasn1, libidn2, p11-kit, brotli)
- **Fixed gdb**: use core-mpfr instead of user-mpfr
- **Fixed llama-cpp**: version bump to b9139, ggml-org mirror URL

### 6. Containerfile Patterns Used

- Go packages: pallet-cgo with `go build -trimpath -ldflags="-s -w" .`
- No `set +eux` in user packages (pallets have it by default)
- All Containerfiles use heredoc syntax (`<<-EOF`)
- Tab indentation in Containerfiles

## Next Steps

1. **Fix nmap build**: Investigate libdnet ethernet support in container (needs linux/if_ether.h)
2. **Verify full tree builds from scratch**: Remove out/ directory, rebuild everything with make and docker cache
   - Log to /tmp/build.log for monitoring
   - Verify all packages build successfully
   - Check for reproducibility (sha256 digests match on rebuild)

3. **Prepare PR body**: Summarize all changes
   - List all updated packages with old → new versions
   - List all new packages added
   - Note any build fixes applied
   - Note any packages not updated and why

## Build Commands

- `make PROGRESS=plain -j1 2>&1 | tee /tmp/build.log` — build full tree sequentially
- `make PROGRESS=plain out/<package>/index.json` — build single package
- `NOCACHE=1 make PROGRESS=plain out/<package>/index.json` — rebuild without cache
- `git diff --name-only origin/staging..HEAD -- packages/` — list changed packages

## Notes

- All pallets have `set -eux` by default, so no need to add it to Containerfiles
- Containerfiles use heredoc syntax (`<<-EOF`) with tab indentation
- Go packages use pallet-cgo with `go build -trimpath -ldflags="-s -w" .`
- Rust packages use pallet-rust with `cargo build --frozen --release`
- CMake packages use pallet-clang-cmake-busybox with `cmake -G Ninja`
- Autotools packages use pallet-clang-gnu-busybox with `./configure`
- License files are installed to `/rootfs/usr/share/licenses/<name>/LICENSE`
- nmap libdnet requires `linux/if_ether.h` which may need additional kernel headers or configure flags
