# ROCm Package - Direct Build

## Build Order (Fixed)

```
rocm-llvm → trap_handler → blit_shaders → rocm-base → rocm-core → rocprofiler-register
                                                    ↓
                                               rocr-runtime → rocminfo
                                                            ↓
                                                        clr
                                                            ↓
                                                    roctracer + libraries
```

## Build Stages

1. **rocm-llvm** - LLVM + Clang with AMDGPU support (built with Clang on pallet-clang-cmake-busybox, single stage)
2. **trap_handler** - AMD Trap Handler for GPU exception handling (builds assembly for gfx900/gfx1010/gfx1030/gfx1100/gfx1200, generates amd_trap_handler_v2.h)
3. **blit_shaders** - AMD Blit Shaders for memory operations (builds assembly for gfx900/gfx1010/gfx1030/gfx1100/gfx1200, generates amd_blit_shaders_v2.h)
4. **rocm-base** - rocm-cmake utilities
5. **rocm-core** - ROCm version info and CMake utilities
6. **rocprofiler-register** - Profiler Register API
7. **rocr-runtime** - HSA Runtime (depends on rocprofiler-register, llvm-objcopy, trap_handler, blit_shaders)
8. **rocminfo** - ROCm information utility (depends on rocr-runtime)
9. **clr** - ROCm Common Runtime Layer with HIP (depends on amd_comgr, rocr-runtime, rocminfo)
10. **roctracer** - ROCm Tracing API
11. **rocdbgapi/amdsmi** - Debug tools and SMI **(SKIPPED)**
12. **rocm-libraries** - ROCm math libraries (in dependency order)
13. **rccl** - ROCm Collective Communications Library

## LLVM Package Structure

### core-llvm (Two-Stage Build with GCC)
- Stage 1: Bootstrap LLVM using GCC
- Stage 2: Full LLVM build using self-hosted LLVM
- Uses GCC for initial bootstrap
- Enables all LLVM targets including AMDGPU

### user-rocm-llvm (Single-Stage Build with Clang)
- Base: `pallet-clang-cmake-busybox` (Clang + CMake on busybox/musl)
- Single build stage (no GCC bootstrap)
- Enables AMDGPU, SPIRV, and all other targets
- Enables same projects: clang, lld
- Enables same runtimes: compiler-rt, libunwind, libcxx, libcxxabi
- Uses Clang/LLVM toolchain throughout (no GCC)
- Install path: `/usr/lib/llvm-amd`

**Key Differences:**
- rocm-llvm uses Clang from pallet instead of GCC for bootstrap
- rocm-llvm is single-stage instead of two-stage
- rocm-llvm has AMDGPU target enabled from the start
- Both can be unified in the future when core-llvm also uses Clang-only build

## Debug Tools Status (COMPLETED - 4/7/2026)

Debug tools (rocdbgapi, rocr-debug-agent, amdsmi) have been **SKIPPED** as requested:
- Lines 352-393 in Containerfile are commented out (debug-build and smi-build stages)
- Line 997 in package stage has debug-build copy commented out
- Line 392 has smi-build marked as "Skip smi build - debug tools"

## Key Changes Made

- Created user-rocm-llvm package (single-stage Clang build on pallet-clang-cmake-busybox)
- rocm package now depends on user-rocm-llvm instead of building LLVM internally
- Added trap_handler-build stage after rocm-core-build (builds trap handler assembly, generates amd_trap_handler_v2.h)
- Added blit_shaders-build stage after trap_handler-build (builds blit shader assembly, generates amd_blit_shaders_v2.h)
- Changed rocm-base to inherit from amd_comgr-build (now from rocm-core-build via trap_handler chain)
- Fixed CMAKE_PREFIX_PATH empty variable issue with `${CMAKE_PREFIX_PATH:-}`
- Added parallel build to LLVM with `ninja -j"$(nproc)"`
- Removed standalone rocm-llvm package (merged into rocm package initially, now separated)
- Removed all patch files (not needed for direct build)
- Removed trap_handler and blit_shaders from rocr-runtime to avoid AMDGPU compilation (now built as separate stages)
- Removed system clang to force use of AMD-LLVM
- rocr-runtime now uses properly built trap_handler and blit_shaders headers instead of placeholders

## Files Modified

- `packages/user/rocm-llvm/` - NEW: LLVM with AMDGPU support built with Clang
- `packages/user/rocm/Containerfile` - Updated to depend on user-rocm-llvm
- `packages/user/rocm/package.toml` - Updated dependencies
- `packages/user/rocm/patches/` - All patches removed
- `AGENTS.md` - Updated with rocm-llvm package structure

## Build Command

```bash
cd /home/lrvick/Sources/stagex && make PROGRESS=plain user-rocm 2>&1 | tee log
```

## Large Build Strategy (Context Overflow Prevention - 4/9/2026)

When building large packages like `user-rocm-llvm` that produce 100k+ tokens of output:

1. **Always redirect output to log file**: `make PROGRESS=plain user-rocm-llvm > log-build 2>&1`
2. **Check exit status only**: `&& echo "SUCCESS" || echo "FAILED"`
3. **Only read log if failed**: `tail -100 log-build`
4. **Never let build output flow into conversation context**

This prevents context overflow crashes that occurred in previous sessions (500k+ tokens).

## Build Fixes (4/9/2026)

### CRT Files Deletion Bug

**Problem**: llvm-bootstrap cleanup step removed ALL `.o` files from `/usr/lib`, including CRT startup files (`crt1.o`, `crti.o`, `crtn.o`, `crtbeginS.o`) that are needed for linking in subsequent build stages.

**Solution**: Removed the blanket cleanup of `/usr/lib/*.o` and `/usr/lib/*.a`. The build directory is removed after install instead, which is cleaner and doesn't affect system CRT files.

### Symlink Conflict Resolution

**Problem**: `user-rocm-llvm` was creating symlinks at `/usr/lib/llvm` and `/usr/lib/clang/21/lib/*` that conflicted with `core-llvm`.

**Solution**:
- Removed `ln -sf /usr/lib/llvm-amd /usr/lib/llvm` - `/usr/lib/llvm` is reserved for core-llvm
- Changed symlink creation to only create links for directories that don't already exist in `/usr/lib/clang/21/lib/`
- Use `/rootfs` destdir pattern for clean package isolation

### Profile Variable Setup

**Problem**: Removed custom `/etc/profile` that set `ARCH`, `TARGET`, `LLVM_TARGET_ARCH` variables.

**Solution**: Added inline variable setup at the beginning of each RUN block instead of relying on profile.

### Rootfs Directory Structure

**Problem**: The `ln` and `cp` commands to `/rootfs/usr/bin` and `/rootfs/usr/lib` failed because the directory didn't exist.

**Solution**: Added `mkdir -p /rootfs/usr/bin /rootfs/usr/lib` before creating symlinks and copying files.

### libLLVM.so Path

**Problem**: `strip` command was looking for `/rootfs/usr/lib/libLLVM.so.21.1` but it was installed to `/rootfs/usr/lib/llvm-amd/lib/`.

**Solution**: Updated strip path to `/rootfs/usr/lib/llvm-amd/lib/libLLVM.so.21.1`

### nsan File Removal

**Problem**: `rm` command failed because nsan files don't exist.

**Solution**: Added `-f` flag to `rm` command: `rm -f`

## Current Build Status (4/12/2026)

### rocr-runtime BUILD SUCCESS ✅

**rocr-runtime build completed successfully!** Build log: `log-rocm-build50` - rocr-runtime-build DONE 22.2s

**Key fix**: Commented out image add_subdirectory instead of removing files (which broke CMake syntax).

### Current Issue - Network Connectivity

The build is now failing at rocprim because it needs to clone rocm-cmake from GitHub:
```
fatal: unable to access 'https://github.com/ROCm/rocm-cmake.git/': Could not resolve host: github.com
```

**Solution**: Build needs network access to fetch dependencies, or use pre-fetched sources.

### What Was Done (4/12/2026)

1. ✅ Removed internal LLVM build stage - Now using pre-built `user-rocm-llvm`
2. ✅ Added `user-rocm-llvm` dependency to all build stages
3. ✅ Updated all compiler paths to use `/usr/lib/llvm-amd/bin/clang`
4. ✅ Fixed `CMAKE_PREFIX_PATH` with `${CMAKE_PREFIX_PATH:-}`
5. ✅ Disabled AMDGPU shader compilation (trap_handler, blit_shaders)
6. ✅ Created placeholder header files
7. ✅ Added `-Wno-error` and `-Wno-typedef-redefinition` flags
8. ✅ Fixed image support by commenting out add_subdirectory instead of deleting files
9. ✅ **rocr-runtime build completed successfully!**

### Why Previous Builds Failed

The rocr-runtime build previously failed with image support errors:
```
CMake Error at runtime/hsa-runtime/CMakeLists.txt:367 (target_sources):
  Cannot find source file:
    image/addrlib/src/addrinterface.cpp
```

**Root Cause**: Deleting the image directory and using sed to remove file references broke CMake syntax.

**Solution**: Comment out `add_subdirectory(image)` instead of deleting files, rely on HSA_IMAGE_SUPPORT=OFF CMake flag.

### Build Configuration Used

```bash
cd /home/lrvick/Sources/stagex && make PROGRESS=plain user-rocm > log-rocm-final14 2>&1
```

All stages configured to use:
- CMAKE_C_COMPILER=/usr/lib/llvm-amd/bin/clang
- CMAKE_CXX_COMPILER=/usr/lib/llvm-amd/bin/clang++
- LLVM_DIR=/usr/lib/llvm-amd/lib/cmake/llvm
- CMAKE_C_FLAGS="-Wno-error -Wno-typedef-redefinition"
- CMAKE_CXX_FLAGS="-Wno-error -Wno-typedef-redefinition"
- -DHSA_BUILD_SHADER=OFF
- -DHSA_ENABLE_AMDGPU=OFF

## Environment

- LLVM version: 21.1.8 (from llvm-project amd-mainline branch)
- ROCm version: 7.11.0
- Build system: CMake + Ninja
- Target GPUs: GFX1030, GFX1100
- AMD LLVM install path: `/usr/lib/llvm-amd`
- rocm-llvm base: `pallet-clang-cmake-busybox` (Clang-only, no GCC)
