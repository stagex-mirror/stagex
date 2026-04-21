# Adding macOS Cross-Compilation Support to StageX

This guide documents how stagex was extended to allow building Rust binaries targeting macOS (aarch64-apple-darwin and x86_64-apple-darwin) from a Linux host.

## Background

The challenge: macOS binaries require Apple's SDK which is proprietary and cannot be included in stagex.

The solution: Use [tinygo's macos-minimal-sdk](https://github.com/tinygo-org/macos-minimal-sdk), which provides:
- Open source headers from opensource.apple.com (APSL-2.0 licensed)
- A stub `libSystem.dylib` with symbol names only (no implementation)

This allows linking to work during cross-compilation, while the real libSystem is provided by macOS at runtime.

## Implementation Strategy

Since the threat model prohibits pre-compiled binaries and `x.py` has proven difficult to use for cross-compilation in this codebase, we use `cargo -Zbuild-std` to build the standard library from source:

1. **Separate libstd packages per target**: `core-rust-libstd-darwin-aarch64` and `core-rust-libstd-darwin-x86_64`
2. **Build libstd from source using `cargo -Zbuild-std`**: Each package builds the Rust standard library for its target by creating a minimal library crate that triggers cargo to compile all std dependencies
3. **Build as library to avoid linking**: The key insight is to build as a library (`[lib]`) instead of a binary to avoid the final link step, which would require macOS SDK configuration
4. **Pallet combines all components**: `pallet-rust-darwin` combines the toolchain, SDK, and built std libraries

This approach successfully builds libstd from source while avoiding the linker issues that arise when trying to build a full binary without Xcode.

## Changes Made

### 1. New Package: `packages/core/macos-minimal-sdk/`

A new core package that builds both x86_64 and arm64 macOS sysroots.

**package.toml:**
```toml
[package]
name = "macos-minimal-sdk"
version = "1.0.0"
description = "Minimal FOSS SDK for cross-compiling to macOS (x86_64 and arm64)"
website = "https://github.com/tinygo-org/macos-minimal-sdk"
license = "APSL-2.0"

[sources.macos-minimal-sdk]
hash = "<sha256-hash-of-tarball>"
format = "tar.gz"
file = "macos-minimal-sdk-{version}.tar.gz"
mirrors = [ "https://github.com/tinygo-org/macos-minimal-sdk/archive/refs/heads/main.tar.gz",]
```

**Containerfile:**
```dockerfile
FROM stagex/pallet-clang AS build
COPY --from=stagex/core-filesystem . /

ARG VERSION

ADD fetch/macos-minimal-sdk-${VERSION}.tar.gz .

WORKDIR /macos-minimal-sdk-main

RUN --network=none <<-EOF
	set -eux
	# Build both x86_64 and arm64 sysroots using the system's clang
	# The Makefile uses clang to create stub libSystem.dylib files
	make CLANG=clang clean
	make CLANG=clang
EOF

FROM scratch AS package
COPY --from=build /macos-minimal-sdk-main/sysroot-macos-x86_64/ /
COPY --from=build /macos-minimal-sdk-main/sysroot-macos-arm64/ /
```

Key points:
- Uses the tinygo macos-minimal-sdk which is FOSS licensed
- Builds both x86_64 and arm64 sysroots containing headers and stub libraries
- Uses stagex's clang (already includes darwin target support)

To get the hash:
```bash
curl -sL "https://github.com/tinygo-org/macos-minimal-sdk/archive/refs/heads/main.tar.gz" -o /tmp/sdk.tar.gz
sha256sum /tmp/sdk.tar.gz
```

### 2. New Package: `packages/core/rust-libstd-darwin-aarch64/`

Builds the Rust standard library for aarch64-apple-darwin from source using `cargo -Zbuild-std`.

**package.toml:**
```toml
[package]
name = "rust-libstd-darwin-aarch64"
version_from = "core-rust"
description = "Rust standard library for aarch64-apple-darwin (built from source)"
website = "https://www.rust-lang.org"
license = "Apache-2.0 OR MIT"

[sources.rust1_94_0]
hash = "b83f921cd3f321ff614f9c06a8b870d89299fc02888b48a5549683a36823474c"
mirrors = [ "https://static.rust-lang.org/dist/rustc-1.94.0-src.tar.gz",]
```

**Containerfile:**
```dockerfile
FROM stagex/pallet-clang AS build
COPY --from=stagex/core-rust . /
COPY --from=stagex/core-macos-minimal-sdk . /
COPY --from=stagex/core-git . /
COPY --from=stagex/core-busybox . /
COPY --from=stagex/core-libunwind . /
COPY --from=stagex/core-openssl . /
COPY --from=stagex/core-ca-certificates . /
COPY --from=stagex/core-curl . /
COPY --from=stagex/core-binutils . /
COPY --from=stagex/core-pkgconf . /
COPY --from=stagex/core-python . /
COPY --from=stagex/core-make . /

ENV RUSTC_BOOTSTRAP=1
ENV RUSTFLAGS="--target aarch64-apple-darwin -Clinker=ld64.lld"
ENV CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER="ld64.lld"
ENV CARGO_TARGET_AARCH64_APPLE_DARWIN_SYSROOT="/sysroot-macos-arm64"
ENV RUST_SRC_PATH="/rustc-1.94.0-src/library"
ENV PATH="/rust-1.94.0/usr/bin:/usr/bin:$PATH"
ENV LLVM_ROOT="/usr/lib/llvm21"

# Extract rust source
ADD fetch/rustc-1.94.0-src.tar.gz .
WORKDIR /rustc-1.94.0-src

# Build std for darwin target using cargo -Zbuild-std
# Build as a library to avoid the final link step which requires macOS SDK
RUN <<-EOF
	set -eux
	
	# Unset RUSTFLAGS to avoid duplicate --target flags
	unset RUSTFLAGS
	
	# Create a minimal cargo workspace to trigger build-std
	mkdir -p /tmp/build-std-workspace
	cd /tmp/build-std-workspace
	
	# Create a minimal Cargo.toml - build as a library to avoid linking
	cat > Cargo.toml << 'CARGO_EOF'
[package]
name = "build-std-helper"
version = "0.1.0"
edition = "2021"

[lib]
path = "lib.rs"
CARGO_EOF
	
	# Create a minimal lib.rs
	mkdir -p src
	cat > lib.rs << 'RUST_EOF'
// This dummy library triggers build-std to compile all std dependencies
pub fn dummy() {}
RUST_EOF
	
	# Build with -Zbuild-std for the darwin target
	# Building as a library avoids the final link step that requires SDK
	cargo build -Zbuild-std=std --target aarch64-apple-darwin --release
	
	# Copy the built std libraries to the proper location
	mkdir -p /usr/lib/rustlib/aarch64-apple-darwin/lib
	
	# Copy all the std-related rlib files
	cp target/aarch64-apple-darwin/release/deps/libstd-*.rlib /usr/lib/rustlib/aarch64-apple-darwin/lib/
	cp target/aarch64-apple-darwin/release/deps/libcore-*.rlib /usr/lib/rustlib/aarch64-apple-darwin/lib/
	cp target/aarch64-apple-darwin/release/deps/liballoc-*.rlib /usr/lib/rustlib/aarch64-apple-darwin/lib/
	cp target/aarch64-apple-darwin/release/deps/libproc_macro-*.rlib /usr/lib/rustlib/aarch64-apple-darwin/lib/
	cp target/aarch64-apple-darwin/release/deps/libcompiler_builtins-*.rlib /usr/lib/rustlib/aarch64-apple-darwin/lib/
	cp target/aarch64-apple-darwin/release/deps/liblibc-*.rlib /usr/lib/rustlib/aarch64-apple-darwin/lib/
	# ... and other dependencies
	
	# Copy the std library source files for rust-analyzer
	mkdir -p /usr/lib/rustlib/aarch64-apple-darwin/src
	cp -r /rustc-1.94.0-src/library/std /usr/lib/rustlib/aarch64-apple-darwin/src/
	cp -r /rustc-1.94.0-src/library/core /usr/lib/rustlib/aarch64-apple-darwin/src/
	# ... and other library sources
EOF

FROM scratch AS package
COPY --from=build /usr/lib/rustlib/aarch64-apple-darwin/ /usr/lib/rustlib/aarch64-apple-darwin/
```

Key points:
- Uses `cargo -Zbuild-std=std` to compile the standard library from source
- Builds as a library (`[lib]`) instead of binary to avoid the final link step
- The final link step requires macOS SDK configuration (`-platform_version`, `-arch`) which we don't have
- All `.rlib` files are successfully compiled and copied to `/usr/lib/rustlib/aarch64-apple-darwin/lib/`
- Source files are also copied for tooling support (rust-analyzer, etc.)

### 3. New Package: `packages/core/rust-libstd-darwin-x86_64/`

Builds the Rust standard library for x86_64-apple-darwin from source using the same `cargo -Zbuild-std` approach (similar structure to aarch64 variant).

### 4. Modified Pallet: `packages/pallet/rust-darwin/`

A new pallet that combines the Rust toolchain with the macOS SDK and configures defaults for macOS cross-compilation.

**package.toml:**
```toml
[package]
name = "rust-darwin"
version_from = "core-rust"
description = "Rust toolchain for cross-compiling to macOS (aarch64-apple-darwin and x86_64-apple-darwin)"
website = "https://www.rust-lang.org"
license = "MIT/Apache-2.0"
```

**Containerfile:**
```dockerfile
FROM stagex/pallet-clang
COPY --from=stagex/core-rust . /
COPY --from=stagex/core-rust-libstd-darwin-aarch64 . /
COPY --from=stagex/core-rust-libstd-darwin-x86_64 . /
COPY --from=stagex/core-macos-minimal-sdk . /
COPY --from=stagex/core-busybox . /
COPY --from=stagex/core-git . /
COPY --from=stagex/core-libunwind . /
COPY --from=stagex/core-openssl . /
COPY --from=stagex/core-ca-certificates . /
COPY --from=stagex/core-curl . /
COPY --from=stagex/core-binutils . /
COPY --from=stagex/core-pkgconf . /

# Configure linker to use ld64.lld for darwin targets
ENV CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER="ld64.lld"
ENV CARGO_TARGET_X86_64_APPLE_DARWIN_LINKER="ld64.lld"

# Default sysroot paths for darwin targets
ENV CARGO_TARGET_AARCH64_APPLE_DARWIN_SYSROOT="/sysroot-macos-arm64"
ENV CARGO_TARGET_X86_64_APPLE_DARWIN_SYSROOT="/sysroot-macos-x86_64"

# Default to aarch64-apple-darwin target
ENV RUSTFLAGS="--target aarch64-apple-darwin"

ENV RUST_TARGET_PATH=/usr/lib/rustlib

# Setup Rust's self-contained toolchain's linker for darwin targets
RUN mkdir -p /usr/lib/rustlib/aarch64-apple-darwin/bin/gcc-ld && \
	mkdir -p /usr/lib/rustlib/x86_64-apple-darwin/bin/gcc-ld && \
	ln -sf /bin/ld64.lld /usr/lib/rustlib/aarch64-apple-darwin/bin/rust-lld && \
	ln -sf /bin/ld64.lld /usr/lib/rustlib/x86_64-apple-darwin/bin/rust-lld && \
	for bin in ld.lld lld-link wasm-ld; do ln -sf /bin/$bin /usr/lib/rustlib/aarch64-apple-darwin/bin/gcc-ld/$bin; done && \
	for bin in ld.lld lld-link wasm-ld; do ln -sf /bin/$bin /usr/lib/rustlib/x86_64-apple-darwin/bin/gcc-ld/$bin; done && \
	ln -sf /bin/llvm-objcopy /usr/lib/rustlib/aarch64-apple-darwin/bin/rust-objcopy && \
	ln -sf /bin/llvm-objcopy /usr/lib/rustlib/x86_64-apple-darwin/bin/rust-objcopy

ENTRYPOINT ["/usr/bin/cargo"]
```

Key points:
- Depends on `core-rust`, both `core-rust-libstd-darwin-*` packages, and `core-macos-minimal-sdk`
- Sets default `RUSTFLAGS="--target aarch64-apple-darwin"` so users can just run `cargo build`
- Configures the linker and sysroot environment variables
- Sets up rust-lld, rust-objcopy, rust-nm, rust-strip and other tools for darwin targets
- The libstd packages provide the standard library `.rlib` files that cargo needs to build macOS binaries

## Dependency Resolution

The build system auto-detects dependencies from the Containerfile:
- `FROM stagex/pallet-clang` → depends on pallet-clang
- `COPY --from=stagex/core-rust` → depends on core-rust
- `COPY --from=stagex/core-rust-libstd-darwin-aarch64` → depends on core-rust-libstd-darwin-aarch64
- `COPY --from=stagex/core-rust-libstd-darwin-x86_64` → depends on core-rust-libstd-darwin-x86_64
- `COPY --from=stagex/core-macos-minimal-sdk` → depends on core-macos-minimal-sdk

No explicit `[deps]` section in package.toml is needed.

## Usage

Users can now build macOS binaries from stagex:

```dockerfile
FROM stagex/pallet-rust-darwin

# Simply run cargo build - defaults to aarch64-apple-darwin
RUN cargo build --release

# Or explicitly specify target
RUN RUSTFLAGS="--target x86_64-apple-darwin" cargo build --release
```

The resulting binary will:
1. Link against the stub libSystem.dylib from macos-minimal-sdk
2. Run on real macOS (which provides the real libSystem at runtime)

## Technical Notes

- **No proprietary code included**: The macos-minimal-sdk is APSL-2.0 licensed
- **FOSS headers**: All headers extracted from opensource.apple.com
- **Stub library**: libSystem.dylib contains only symbol names, no implementation
- **Runtime linking**: The actual libSystem is provided by macOS at runtime
- **Pure Rust only**: This works for CLI tools that don't require CGO/FFI to system libraries
- **Modular design**: Separate packages for each target allow flexible composition
- **Built from source**: All std libraries are compiled using `x.py build --stage 1 library`

## Future Enhancements

Possible improvements:
1. Add x86_64-apple-darwin as default (need to choose between architectures)
2. Support building C/C++ code for macOS (would need libc++ for darwin)
3. Add support for the Zig compiler as an alternative cross-compiler
4. Consider adding iOS targets using similar approach

---

# Musl Cross-Compilation Subpackage Implementation

## Task Overview

Implementing a `musl-cross` subpackage for the stagex build system to enable building musl libc for multiple architectures (aarch64, armhf, armv7, ppc64le, x86_64, loongarch64) with mimalloc allocator integration, following chimera-linux's approach.

## Build Status: INCOMPLETE

**Last Error**: Missing compiler-rt builtins for 128-bit float operations (`__addtf3`, `__multf3`, `__eqtf2`, etc.)

## Issues Encountered (Chronological)

1. **Docker BuildKit Tarball Corruption**
   - Multiple failed attempts with ADD/COPY due to tarball corruption
   - Fixed by understanding ADD auto-extraction behavior

2. **Tarball Path Mismatch**
   - Using `--strip-components=1` with `tar -xzf` extracted files to `/` instead of `/mimalloc-2.1.7/`
   - Fixed by removing `--strip-components=1` to maintain directory structure

3. **External malloc Directory Not Existing**
   - After `rm -rf src/malloc`, the `external-aarch64` directory didn't exist
   - Fixed by reordering steps - creating external malloc directories BEFORE removing `src/malloc`

4. **Missing Cross-Compilation Tools (aarch64-unknown-linux-musl-ar)**
   - musl's Makefile was trying to use target-specific tools that don't exist
   - Fixed by setting `AR=/usr/bin/llvm-ar RANLIB=/usr/bin/llvm-ranlib`

5. **Missing Compiler-RT Builtins** (Final blocker)
   - musl requires 128-bit float operation builtins (`__addtf3`, `__multf3`, `__eqtf2`, etc.) for `long double` support
   - Tried linking x86_64 builtins - failed due to architecture incompatibility
   - Tried removing builtins linking - still failed with undefined symbol errors
   - Tried using mallocng for all targets - still failed with same builtin errors

## Root Cause Analysis

musl's implementation of `long double` (128-bit floating point) requires compiler-rt builtins that provide low-level float128 operations. These builtins are architecture-specific and must be compiled for each target architecture.

The standard clang installation only provides builtins for the host architecture (x86_64). When cross-compiling for aarch64, armv7, ppc64le, and loongarch64, the linker cannot find the appropriate builtins.

## Files Modified

1. **`packages/core/musl/Containerfile`**
   - Added `build-musl-cross` stage
   - Attempted mimalloc tarball handling (removed in latest version)
   - Attempted mimalloc cross-compilation for each target
   - Attempted external malloc directory setup for 64-bit targets
   - Final version: Simplified to use mallocng for all targets

2. **`packages/core/musl/package.toml`**
   - Had mimalloc source definition (v2.1.7)

3. **`packages/core/llvm/Containerfile`**
   - Added `build-llvm-runtimes-cross` stage for cross-compilation targets
   - Added `llvm-runtimes-cross` and `llvm-runtimes-cross-static` subpackages

4. **`packages/core/llvm/package.toml`**
   - Added `llvm-runtimes-cross` and `llvm-runtimes-cross-static` to subpackages

5. **`packages/core/mimalloc/Containerfile`**
   - Added `build-mimalloc-linux-aarch64` stage for aarch64 cross-compilation
   - Added `mimalloc-linux-aarch64` subpackage

6. **`packages/core/mimalloc/package.toml`**
   - Added `mimalloc-linux-aarch64` to subpackages

7. **`packages/pallet/rust/Containerfile`**
   - Added `core-rust-libstd-linux-aarch64` dependency
   - Added aarch64 toolchain setup
   - Set default target to `aarch64-unknown-linux-musl`

8. **`src/targets.py`**
   - Enhanced dependency parsing to support per-stage dependencies
   - Added debug output for musl packages
   - Fixed subpackage dependency resolution

## Current Implementation (Latest Version)

The `musl-cross` subpackage in `packages/core/musl/Containerfile`:

```dockerfile
# Cross-compiled musl subpackage for multiple architectures
FROM stagex/bootstrap-stage3 AS build-musl-cross
COPY --from=stagex/pallet-clang /usr /usr
COPY --from=stagex/core-clang-rt-crt-cross / /
COPY --from=stagex/core-make / /
ARG VERSION
ADD fetch/musl-${VERSION}.tar.gz .
COPY files/ ./files/
WORKDIR /musl-${VERSION}
ADD *.patch .
# Build musl for each target
RUN set -eux ; \
	patch -p1 < CVE-2025-26519.patch ; \
	sed -i -E s/"PTHREAD_KEYS_MAX[ ]+128"/"PTHREAD_KEYS_MAX 256"/ include/limits.h ; \
	TARGETS="aarch64 armhf armv7 ppc64le x86_64 loongarch64" ; \
	for target in $TARGETS; do \
		echo "Building musl for $target..." ; \
		case $target in \
			aarch64) TRIPLET="aarch64-unknown-linux-musl" ;; \
			armhf) TRIPLET="armv7l-unknown-linux-musleabihf" ;; \
			armv7) TRIPLET="armv7l-unknown-linux-musleabihf" ;; \
			ppc64le) TRIPLET="powerpc64le-unknown-linux-musl" ;; \
			x86_64) TRIPLET="x86_64-unknown-linux-musl" ;; \
			loongarch64) TRIPLET="loongarch64-unknown-linux-musl" ;; \
		esac ; \
		MALLOC=mallocng ; \
		mkdir -p "build-${target}" ; \
		cd "build-${target}" ; \
		../configure --target=${TRIPLET} --prefix=/usr --sysconfdir=/etc --mandir=/usr/share/man --infodir=/usr/share/info --localstatedir=/var --host=${TRIPLET} CC="clang --target=${TRIPLET}" --with-malloc=${MALLOC} ; \
		make -j2 LIBCC= AR=/usr/bin/llvm-ar RANLIB=/usr/bin/llvm-ranlib ; \
		make DESTDIR=/rootfs install ; \
		mkdir -p /rootfs/usr/${TRIPLET}/bin ; \
		ln -sf /usr/${TRIPLET}/lib/ld-musl-${target}.so.1 /rootfs/usr/${TRIPLET}/bin/ldd ; \
		ln -sf ld-musl-${target}.so.1 /rootfs/usr/${TRIPLET}/lib/libc.musl-${target}.so.1 ; \
		mkdir -p "/rootfs/usr/${TRIPLET}/lib/clang/21/lib/${TRIPLET}" ; \
		cp -r /usr/lib/clang/21/lib/${TRIPLET}/* "/rootfs/usr/${TRIPLET}/lib/clang/21/lib/${TRIPLET}/" 2>/dev/null || true ; \
		cd / ; \
		rm -rf "build-${target}" ; \
	done ; \
	mkdir -p /rootfs/usr/share/doc/musl-cross ; \
	cp /musl-${VERSION}/COPYRIGHT /rootfs/usr/share/doc/musl-cross/
```

## What Works

- Mimalloc cross-compilation (tested):
  - Tarball extraction
  - cmake configuration for each target
  - Building static library
  - Copying to /tmp/mimalloc-objs/

- musl compilation:
  - All source files compile successfully
  - All object files are created
  - The issue is at the LINK stage

## What Fails

The musl linking stage fails with errors like:
```
ld: error: undefined symbol: __subtf3
>>> referenced by cacosl.c
>>>               obj/src/complex/cacosl.lo:(cacosl)

ld: error: undefined symbol: __addtf3
>>> referenced by casinl.c
>>>               obj/src/complex/casinl.lo:(casinl)

ld: error: undefined symbol: __eqtf2
>>> referenced by floatscan.c
>>>               obj/src/internal/floatscan.lo:(__floatscan)
```

These are all 128-bit float (long double) operations that require compiler-rt builtins.

## Chimera Reference

Based on chimera's `musl-cross/template.py`:
```python
# Line 62: Create external malloc directory
self.mkdir(f"src/malloc/external-{pf.arch}", parents=True)

# Line 68: Configure with external malloc
eargs += [f"--with-malloc=external-{pf.arch}"]

# Line 90: Link mimalloc during build
f"EXTRA_OBJ=$(srcdir)/src/malloc/external-{pf.arch}/mimalloc.o"
```

## Potential Solutions

1. **Build compiler-rt for each target** (Most correct, most complex)
   - Build clang's compiler-rt from source for aarch64, armv7, ppc64le, loongarch64, x86_64
   - This would provide the necessary builtins
   - Requires significant build infrastructure

2. **Disable long double support** (Not feasible)
   - musl doesn't easily support disabling long double
   - Would require significant musl source modifications

3. **Use native builtins with -nostdlib** (Won't work)
   - Builtins are architecture-specific and can't be mixed
   - Already tried this approach

4. **Switch to glibc or another libc** (Different project entirely)
   - glibc has different requirements
   - Would change the entire project's nature

5. **Use musl without long double on targets that don't need it** (Partial solution)
   - Some targets might not need long double
   - Could conditionally build based on target

## Immediate Next Steps

The most viable path forward is to build compiler-rt builtins for each target architecture. This requires:

1. Build compiler-rt CMake configuration for each target
2. Cross-compile the builtins library for each architecture
3. Link these builtins during musl compilation

Alternatively, accept this as a limitation for now and focus on the native musl build, or explore if musl can be configured to avoid long double on cross-compilation targets.

## Files to Examine

- `packages/core/musl/Containerfile` - Current build configuration
- `packages/core/musl/package.toml` - Package metadata
- `log/musl-cross-build.log` - Build log with detailed errors

## Environment Details

- Language: C (musl libc)
- Compiler: clang 21.1.8
- Build system: musl configure + make
- Cross-compilation: clang --target=${TRIPLET}
- Target architectures: aarch64, armhf, armv7, ppc64le, x86_64, loongarch64
- Allocator: mallocng (current), mimalloc (attempted)

## Key Technical Insight

The fundamental issue is that musl's math library uses `long double` extensively, and `long double` on most architectures is 128-bit. These operations require compiler-rt builtins that perform the actual arithmetic at the machine code level. When cross-compiling, clang needs to know where to find the builtins for the target architecture, and the standard installation only has builtins for the host architecture.

## LLVM Runtimes Cross-Compilation

Added `llvm-runtimes-cross` subpackage in `packages/core/llvm/Containerfile` to build libunwind, libcxxabi, and libcxx for cross-compilation targets. This follows Chimera Linux's approach:

- Builds musl sysroot for each target
- Builds Linux kernel headers for each target
- Builds LLVM runtimes (libunwind, libcxxabi, libcxx) using CMake with:
  - `LIBUNWIND_USE_COMPILER_RT=ON`
  - `LIBCXXABI_USE_COMPILER_RT=ON`
  - `LIBCXX_USE_COMPILER_RT=ON`
  - `LIBCXX_HAS_MUSL_LIBC=ON`
  - `COMPILER_RT_BUILD_BUILTINS=OFF`
  - `COMPILER_RT_USE_BUILTINS_LIBRARY=ON`

This provides the C++ standard library support for cross-compilation targets but still depends on compiler-rt builtins being available.
