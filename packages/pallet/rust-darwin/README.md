# rust-darwin

Rust toolchain for cross-compiling to macOS (`aarch64-apple-darwin`,
`x86_64-apple-darwin`) from a Linux host.

Pre-installed:

- Rust from `core-rust` (same version, same rustc, same cargo).
- Cross rust-std for both Apple triples (`core-rust-std-cross-*-apple-darwin`).
- Minimal APSL-2.0 macOS SDK (`core-macos-minimal-sdk`) at
  `/usr/aarch64-apple-darwin/` and `/usr/x86_64-apple-darwin/`.
- Per-target `CARGO_TARGET_*_APPLE_DARWIN_{LINKER,RUSTFLAGS}` env vars
  routing clang + `ld64.lld` with `--target`/`--sysroot`/
  `-Wl,-undefined,dynamic_lookup`.

## Usage

```dockerfile
FROM stagex/pallet-rust-darwin AS build
COPY . /src
WORKDIR /src
RUN cargo build --release --target=aarch64-apple-darwin
# Output: target/aarch64-apple-darwin/release/<binary> — Mach-O for
# arm64 macOS. Ship or codesign on a real Mac.
```

## Smoke test

```sh
mkdir -p /tmp/darwin-smoke && cd /tmp/darwin-smoke
cat > Cargo.toml <<'TOML'
[package]
name = "hello-darwin"
version = "0.1.0"
edition = "2021"

[[bin]]
name = "hello"
path = "hello.rs"
TOML
printf 'fn main(){println!("hello darwin");}\n' > hello.rs

docker run --rm -v /tmp/darwin-smoke:/src -w /src --entrypoint cargo \
    stagex/pallet-rust-darwin:local \
    build --release --target=aarch64-apple-darwin

file target/aarch64-apple-darwin/release/hello
# Mach-O 64-bit arm64 executable, flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|PIE|HAS_TLV_DESCRIPTORS>
```

Cargo's warning about `xcrun`/MacOSX.sdk is expected — we ship our own SDK
via the sysroot rustflags, and Cargo hasn't been told to look there. The
build still succeeds. Swap `aarch64-apple-darwin` for `x86_64-apple-darwin`
to get an Intel binary.

## Caveats

- The bundled macOS SDK is
  [tinygo-org/macos-minimal-sdk](https://github.com/tinygo-org/macos-minimal-sdk),
  APSL-2.0. It ships a very small stub `libSystem.dylib`; symbols the
  stub doesn't export are resolved by macOS's `dyld` at load time via
  `-Wl,-undefined,dynamic_lookup`. That's normal for cross-Darwin
  builds — no Xcode / no proprietary SDK involved.
- Produced binaries are **unsigned**. Distributing outside your own
  machine typically means codesigning (requires macOS + Apple Developer
  account) and, for Gatekeeper, notarization. Neither is in scope for
  this pallet.
