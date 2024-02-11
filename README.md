# \[Stageˣ\]

[git://codeberg.org:stagex/stagex](https://codeberg.org/stagex/stagex) | [matrix://#stagex:matrix.org](https://matrix.to/#/#stagex:matrix.org) | [ircs://irc.oftc.net:6697#stagex](https://webchat.oftc.net/?channels=stagex&uio=MT11bmRlZmluZWQmMTE9MTk14d)

---

Minimalism and security first repository of reproducible and multi-signed OCI
images of common open source software toolchains full-source bootsrapped from
Stage 0 all the way up.

If you want to build or deploy software on a foundation of minimalism and
determinism with reasonable security, stagex might be the foundation you are
looking for.

## Usage

You can do anything with these images you would with most any other musl based
containerized linux distro, only with high supply chain integrity and
determinism.

For a full list of images see the "src" directory.

### Examples

Get a shell in our x86_64 Stage3 bootstrap image:

```
docker run -it stagex/stage3
```

Run a Python hello world:
```
docker run -i stagex/python -c "print('hello world')"
```

Make a hello world OCI container image with Rust:
```
FROM stagex/busybox as build
COPY --from=stagex/rust . /
COPY --from=stagex/gcc . /
COPY --from=stagex/binutils . /
COPY --from=stagex/libunwind . /
RUN printf 'fn main(){ println!("Hello World!"); }' > hello.rs
RUN rustc hello.rs
FROM scratch
COPY --from=build /home/user/hello .
CMD ["./hello"]
```

### Package Management

Unlike most linux distros, stagex was built for determinism, minimalism, and
containers first, and thus has no concept of a traditional package manager.

In fact, stagex ships no first-party code at all. We just package things in the
most "stock" way possible with exceptions only to maintain determinism.

Every image is "from scratch" and contains an empty filesystem with the
installed package.

By default you always get the latest updates to dependencies on the fly, but
you retain the option for bit-for-bit reproducible builds by locking any given
dependency at a particular tag or image hash.

If you want an old version of rust with a recent version of Gcc to work around
some problem build, you can do that without resorting to low security \
"curl | bash" style solutions like rustup.

## Goals

We built to support very high risk threat models where trusting any single
system or maintainer in our software supply chain cannot be tolerated. That
said, we should also function as a drop-in replacement for musl-based linux
distributions for virtually any threat model.

Our aim is to provide a reasonably secure set of toolchains for every major
programming language to be the basis of your containers, build systems,
firmware, secure enclaves, or hosting infrastructure.

Not all of these goals are 100% realized yet, but should at least help you
decide if this project is something you want to contribute to or keep an eye on
for the future.

### Integrity

* Anyone can reproduce the entire tree with tools from their current distro
* Hosted CI servers auto-sign confirmed deterministic builds
    * Like NixOS
* Maintainers sign all package additions/changes
    * Like Gentoo, Debian, Fedora, Guix
* Reviewers/Reproducers locally build and counter-sign all new binary packages
    * No one does this, as far as we can tell

### Minimalism

* Based on musl libc
    * Basis of successful minimal distros like Alpine, Adelie, Talos, Void
    * Implemented with about 1/4 the code of glibc
    * Required to produce portable static binaries in some languages
    * Less prone to buffer overflows
    * Puts being light, fast, and correct before compatibility
* Package using tools you already have
    * OCI build tool of choice (Docker, Buildah, Podman)
    * Make (for dependency management)
    * Prove hashes of bootstrap layer builds match before proceeding
* Keep package definitions lean and readable with simple CLI and no magic

## Background

We have learned a lot of lessons about supply chain integrity over the years,
and the greatest of them may be that any system that is complex to review and
assigns trust of significant components to single human points of failure, is
doomed to have failure.

Most Linux distributions rely on complex package management systems for which
only a single implementation exists. They assign package signing privileges to
individual maintainers at best. Modern popular distros often fail to even do
this, having a central machine somewhere blindly signing all unsigned
contributions from the public.

We will cover an exhaustive comparison of the supply chain strategies of other
package management solutions elsewhere, but suffice to say while many are
pursuing reproducible builds, minimalism, or signing... any one solution
delivering on all of these does not seem in the cards any time soon.

This is generally a human problem. Most solutions end up generating a lot of
custom tooling for package management, which in turn rapidly grows in
complexity to meet demands ranging from hobby desktop systems production
servers.

This complexity demands a lot of cycles to maintain, and this means in practice
lowering the barrier to entry to allow any hobbyist to contribute and maintain
packages with minimal friction and rarely a requirement of signing keys or
mandatory reproducible builds, let alone multiple signed reproduction proofs.

Suffice to say, we feel every current Linux package management solution and
container supply chain has single points of human failure, or review
complexity, that makes it undesirable for threat models that assume any single
human can be hacked or coerced.

## Comparison

A comparison of `stagex` to other distros in some of the areas we care about:

| Distro | Single-Sig | Multi-Sig |Diver.| Musl | Stage0 | Repro. | Rust Deps |
|--------|------------|-----------|------|------|--------|--------|-----------|
| Stagex | x          | p         | p    | x    | x      | x      | 4         |
| Guix   | x          |           |      |      | x      | x      | 4         |
| Nix    |            |           |      |      |        | p      | 4         |
| Debian | x          |           |      |      |        | p      | 232       |
| Arch   | x          |           |      |      |        | p      | 262       |
| Fedora | x          |           |      |      |        |        | 166       |
| Alpine |            |           |      |      | x      |        | 32        |

### Legend

- x = true
- p = planned
- “Single-sig”: one person, typically the maintainer, signed a given package
    - Some distros blindly sign all packages with a shared accees server
    - We see this as mostly security theater and do not include it here
- “Multi-sig”: more than one human verified/signed every package artifact
    - And ideally also signed the source
- “Diver.”: Can the entire distro be built with a diversity of toolchains
- “Musl”: entire distro and resulting artifacts are built against musl libc
- “Stage0”: Can the entire distro be full-source-bootstrapped from Stage0
- “Repro.”: Is the entire distro reproducible bit-for-bit identically
- “Rust Deps”: the number of total dependencies installed to use rustc
    - Rust is a worst case example for compiler deps and build complexity
        - It is kind of a nightmare most distros skip
        - See: [Guix documenting their process](https://guix.gnu.org/en/blog/2018/bootstrapping-rust/) (similar to ours)
    - Nix, guix, and our distro get away with only 4 deps because:
        - Rustc -does- need ~20 dependencies to build
        - The final resulting rust builds can run standalone
        - We only actually need musl libc, llvm, and gcc to build most projects

### Signatures

* Signatures are made by the PGP public keys in the "keys" directory
* Signatures are made by any tool that implements "[Container Signature Format](https://github.com/containers/image/blob/main/docs/containers-signature.5.md)"
    * We provide a minimal shell script implementation as a convenience
    * Podman also [implements support](https://github.com/containers/podman/blob/main/docs/tutorials/image_signing.md) for this signature scheme
* Signatures are "PR"ed and committed to this repo as a source of truth
* Signatures can be mirrored to any HTTPS url
* Container daemons can verify signatures on pull with a [containers-policy.json](https://github.com/containers/image/blob/main/docs/containers-policy.json.5.md)
* As a policy, we expect all published signers to:
    * Maintain their PGP private keys offline and/or on personal HSMs
        * E.g. Nitrokey, Yubikey, Leger, Trezor, etc.
    * Maintain a public key in the "keys" folder of this repository
    * Maintain a [keyoxide](https://keyoxide.org) profile self-certifying keys
    * Maintain a [Hagrid](https://keys.openpgp.org) profile with verified UIDs
    * Make best efforts to meet in person and sign each others keys
    * Create signatures from highly trusted operating systems
        * E.g Dedicated QubesOS VM, or a an airgapped signing system

### Reproducibility

The only way to produce trustworthy packages is to make sure no single system
or human is every trusted in the process of compiling them. Everything we
release must be built deterministically. Further to avoid trusting any specific
distro or platform, we must be able to reproduce even from wildly different
toolchains, architectures, kernels, etc.

Using OCI container images as our base packaging system helps a lot here by
making it easy to throw away non-deterministic build stages and control many
aspects of the build environment. Also, as a well documented spec, it allows
our packages to (ideally) be built with totally different OCI toolchains such
as Docker, Podman, Kaniko, or Buildah.

This is only part of the story though, because being able to build
deterministically means the compilers that compiler our code themselves must
be bootstapped all the way from source code in a deterministic way.

* Final distributable packages are always OCI container images
    * OCI allows reproduction by totally different toolchains
        E.g: Docker, Podman, Kaniko, or Buildah.
    * OCI allows unlimited signatures on builds as part of the spec
      * E.g: each party that chooses to reproduce adds their own signature
* We always "Full Source Bootstrap" everything from 0
    * [Stage0](src/bootstrap/stage0/Dockerfile): 387 bytes of x86 assembly built by 3 distros with the same hash
        * Also the same hash many others get from wildly different toolchains
        * Relevant: [Guix: Building From Source All The Way Down](https://guix.gnu.org/en/blog/2023/the-full-source-bootstrap-building-from-source-all-the-way-down/)
    * [Stage1](src/bootstrap/stage1/Dockerfile): A full x86 toolchain built from stage0 via [live-bootstrap](https://github.com/fosslinux/live-bootstrap/blob/master/parts.rst)
    * [Stage2](src/bootstrap/stage2/Dockerfile): Cross toolchain bridging us to modern 64 bit architectures
    * [Stage3](src/bootstrap/stage3/Dockerfile): Native toolchain in native 64 bit architecture
    * [Stage(x)](.): Later stages build the distributed packages in this repo

For further reading see the [Bootstrappable Builds](https://bootstrappable.org/) Project.

## Building

### Requirements

* An OCI building runtime
    * Currently Docker supported, but will support buildah and podman
* Gnu Make

### Examples

#### Compile all packages

```
make
```

#### Compile specific package

```
make out/rust.tgz
```

#### Reproduce all changed packages

```
make reproduce
```

#### Reproduce all packages without cache

```
make clean reproduce
```

#### Sign current manifest of package hashes

```
make sign
```

## Packaging

Every package should have a minimum of 5 stages as follows

* base
    * based on busybox or bootstrap
    * Runs as unprivileged user 1000 (user)
    * Sets environment to be shared with fetch, build, and install stages
    * Imports dependencies for fetch, build, and install stages
* fetch
    * Based on "base"
    * Runs as unprivileged user 1000 (user)
    * Has internet access
    * Obtains any needed source files from the internet
    * Verifies sources against hardcoded hashes
* build
    * Based on "fetch"
    * Runs as unprivileged user 1000 (user)
    * Extract sources
    * Apply any patches as needed
    * Build any artifacts as needed
* install
    * Based on "build"
    * Elevates privileges to user 0:0 (root)
    * Installs all files in /home/user/rootfs owned by root
    * Sets all timestamps in /home/user/rootfs to @0 (Unix Epoch)
* package
    * Based on scratch
    * Copies /home/user/rootfs from "install" to /
    * Sets runtime user/perms/env as needed

## Sponsors

- [Turnkey](https://turnkey.com)
- [Distrust](https://distrust.co)
- [Mysten Labs](https://mystenlabs.com)
