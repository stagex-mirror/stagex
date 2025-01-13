# Stages

StageX is split into multiple stages of development, which allows StageX to be
built in parts, described below.

## Adding a Package

Unless adding a compiler (in which case, the compiler should be added to `core`
and a pallet should be created), packages should generally be added to the
`user` stage.

> [!NOTE]
If you just want to add a package, and it's not a compiler or a new programming
language, you can likely skip the rest of this document.

## Bootstrap

The `bootstrap` stage is designed to go from as small a seed as possible to a
usable C compiler.

## Core

Core packages are used to build Pallets, and should only rely on either other
core packages or bootstrap packages. Core packages can either be included in
pallets or used to build later packages. Core includes a mix of interpreters,
compilers, and the dependencies required to run both.

## Pallets

Pallets are the "base" of most StageX packages. They're also the only package
that ships "dependencies included", meaning they can be run independently.

### Pallet Example

In the below pallet example, no other dependencies are required, as the pallet
is designed to ship with all necessary default dependencies. Earlier versions
of StageX required including dependencies such as `musl`, `libunwind`, and
`binutils` to build Rust programs, but this is no longer necessary.

```dockerfile
FROM stagex/pallet-rust

COPY <<-EOF ./hello.rs
fn main(){
    println!("Hello World!");
}
EOF

RUN ["rustc","-C","target-feature=+crt-static","-o","hello","hello.rs"]

FROM scratch
COPY --from=build /hello .
ENTRYPOINT ["/hello"]
```

### Adding a Pallet

> [!WARNING]
When creating a new pallet, make sure all dependencies required are in `core`,
as pallets are not supposed to pull packages from `user`. If a required package
is in `user`, it can be "promoted" to `core`.

Pallets are designed to ship all dependencies required to make the "average
case example" work. This means dependencies that are not necessarily required
by the minimum case may also be included - developers who wish to reduce attack
surface by all costs can instead compose their own dependencies. For example,
the Rust pallet ships with `openssl` and `ca-certificates` to pull dependencies
from a registry if necessary.

## User

User packages are built using pallets when available and may be used to build
other user packages. They contain all packages that are not required by
pallets. User packages can be used when building operating systems such as
[AirgapOS] or [ReprOS], or shipped as dependencies or binaries in a container.

[AirgapOS]: https://git.distrust.co/public/airgapos
[ReprOS]: https://codeberg.org/stagex/repros
