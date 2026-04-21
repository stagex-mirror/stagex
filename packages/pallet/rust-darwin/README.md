# rust-darwin Pallet

This pallet provides a Rust toolchain configured for cross-compiling to macOS (aarch64-apple-darwin and x86_64-apple-darwin) from a Linux host.

## Features

- Rust 1.94.0 toolchain
- macOS minimal SDK from tinygo-org/macos-minimal-sdk
- Configured linker (ld64.lld) for darwin targets
- Default target: aarch64-apple-darwin
- Rust source available at `/rustc-1.94.0-src/library` for `-Zbuild-std`

## Building macOS Binaries from Source

To build macOS binaries entirely from source (no prebuilt stdlib), use cargo's `-Zbuild-std` feature with nightly Rust:

### Option 1: Bring your own nightly toolchain

```dockerfile
FROM stagex/pallet-rust-darwin

# Install nightly Rust (downloads from rust-lang.org)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly-x86_64-unknown-linux-gnu

WORKDIR /app
COPY . .

# Build with -Zbuild-std to compile std from source
# Uses the local rust source at RUST_SRC_PATH
RUN cargo build -Zbuild-std=std,core,alloc --target aarch64-apple-darwin --release
```

### Option 2: Pre-install nightly in your own base

You can pre-install nightly in your own Dockerfile before using this pallet:

```dockerfile
FROM stagex/pallet-clang

# Install nightly Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly-x86_64-unknown-linux-gnu

# Then copy from rust-darwin
COPY --from=stagex/pallet-rust-darwin / /

WORKDIR /app
COPY . .

RUN cargo build -Zbuild-std=std,core,alloc --target aarch64-apple-darwin --release
```

## Environment Variables

- `RUSTFLAGS="--target aarch64-apple-darwin"` - Default target
- `CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER="ld64.lld"` - Linker for aarch64
- `CARGO_TARGET_X86_64_APPLE_DARWIN_LINKER="ld64.lld"` - Linker for x86_64
- `CARGO_TARGET_AARCH64_APPLE_DARWIN_SYSROOT="/sysroot-macos-arm64"` - Sysroot for aarch64
- `CARGO_TARGET_X86_64_APPLE_DARWIN_SYSROOT="/sysroot-macos-x86_64"` - Sysroot for x86_64
- `RUST_SRC_PATH="/rustc-1.94.0-src/library"` - Path to Rust source for -Zbuild-std

## Building for x86_64

To build for x86_64 instead of aarch64:

```bash
RUSTFLAGS="--target x86_64-apple-darwin" cargo build -Zbuild-std=std,core,alloc --release
```

## Notes

- The `-Zbuild-std` feature requires nightly Rust
- The Rust source is included in the pallet at `/rustc-1.94.0-src/library`
- `-Zbuild-std` will use this local source instead of downloading prebuilt stdlib
- Pure Rust binaries work without additional dependencies
- The macOS minimal SDK provides headers and stub libraries for linking
