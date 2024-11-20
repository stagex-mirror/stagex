# \[Stageˣ\]

[git://codeberg.org:stagex/stagex](https://codeberg.org/stagex/stagex) | [matrix://#stagex:matrix.org](https://matrix.to/#/#stagex:matrix.org) | [ircs://irc.oftc.net:6697#stagex](https://webchat.oftc.net/?channels=stagex&uio=MT11bmRlZmluZWQmMTE9MTk14d)

[![Donate to StageX's OpenCollective](https://opencollective.com/stagex/donate/button.png?color=white)](https://opencollective.com/stagex/donate)     

---

Minimalism and security first repository of reproducible and multi-signed OCI
images of common open source software toolchains full-source bootstrapped from
Stage 0 all the way up.

If you want to build or deploy software on a foundation of minimalism and
determinism with reasonable security, stagex might be the foundation you are
looking for.

## Usage

You can do anything with these images you would with most any other musl based
containerized linux distro, only with high supply chain integrity and
determinism.

For a full list of images see the "packages" directory.

### Examples

#### Get a shell in our x86_64 Stage3 bootstrap image:

```shell
docker run -it stagex/stage3
```

#### Get a Python shell by using the Python Pallet

```sh
docker run -it stagex/pallet-python -c "print('hello, world!')"
```

#### Make a hello world OCI container image with the Rust pallet

```dockerfile
FROM stagex/pallet-rust AS build

RUN ["cargo", "new", "--bin", "pattern_matcher"]
WORKDIR /pattern_matcher
RUN ["cargo", "add", "regex"]

COPY <<-EOF /pattern_matcher/src/main.rs
use regex::Regex;

fn main() {
    let mut args = std::env::args();
    args.next();
    let pattern = args.next().expect("pattern not given");
    let text = args.next().expect("text to match not given");
    let re = Regex::new(&pattern).expect("given pattern is invalid regex");
    if let Some(r#match) = re.find(&text) {
        println!("Found match: {match:?}");
    }
}
EOF

ENV RUSTFLAGS="-C target-feature=+crt-static"
RUN ["cargo", "build", "--release"]

FROM stagex/core-filesystem AS package
COPY --from=build /pattern_matcher/target/release/pattern_matcher /usr/bin/pattern_matcher
ENTRYPOINT ["/usr/bin/pattern_matcher"]
```

Note the difference between the "build" and the final image: `build` has to
pull the `rust` pallet, which includes just the binaries required to build a
Rust program, but the final OCI image only contains the statically compiled
Rust binary, and is tiny as a result.

#### Add dependencies using container-native workflows

Oftentimes, you'll need dependencies that aren't included by default, such as
`clang` when building crates using Rust's `bindgen` crate. StageX makes adding
packages super simple. In your `build` phase, add the following line:

```dockerfile
COPY --from=stagex/core-clang . /
```

No `RUN` commands needed.

### Package Management Policies

Unlike most linux distros, stagex was built for determinism, minimalism, and
containers first, and thus has no concept of a traditional package manager.
In fact, stagex ships no first-party code at all. We just package things in the
most "stock" way possible with exceptions only to maintain determinism.

Every image is "from scratch" and contains an empty filesystem with the
installed package.

By default you always get the latest updates to dependencies on the fly, but
you retain the option for bit-for-bit reproducible builds by locking any given
dependency at a particular tag or image hash.

If you want an old version of rust with a recent version of GCC to work around
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
* Multiple maintainers reproduce the entire build and ensure that everything
matches down to the last bit
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
and the greatest of them may be that any system that is complex to review 
and assigns trust of significant components to single individuals, which creates 
significant points of failure, will lead to eventual compromise.

Distros (Linux distributions) rely on complex package management systems for 
which only a single implementation exists. They typically generate a lot of 
custom tooling, which in turn rapidly grows in complexity to meet demands 
ranging from hobby desktops to production servers. This complexity demands a 
lot of effort to maintain, and in practice results in a tendency to reduce 
security overhead in order to lower the barrier to entry to attract more 
maintainers. As a result, projects rarely mandate cryptographic signing or 
reproducible builds, let alone multiple signed reproduction proofs. In fact, 
some popular distros use a server to blindly sign all contributions from the 
public, which can give a false sense of security to the unassuming user.

We will cover an exhaustive comparison of the supply chain strategies of other 
package management solutions elsewhere, but while many are pursuing reproducible 
builds, minimalism, or signing, there isn't currently another solution which delivers 
on all of these basic tenets of supply chain security. `stagex` is an attempt to fix 
this, in order to satisfy the criteria of reasonably secure supply chain strategy, 
which requires more than one individual to deterministically build and sign software.

Ask yourself the following: do I have a way of verifying that this binary was 
produced based on this source code?

While software is often reviewed for security flaws, and sometimes provides signed 
releases, what is missing is the ability to prove that the resulting binary is the 
direct result of that code and nothing has been modified along the way. To achieve 
this, we have to make the software always build the exact same thing, down to the 
last bit - this is what determinism or reproducibility is. You may be reading this 
and thinking "of course it should always build to the same exact binary", but this 
is usually not the case - it's highly unlikely that any of the software you have ever 
built is deterministic. By forcing software to always produce the same binary, we 
can use hashes to easily verify nothing has been modified and no new code has been 
introduced to the software during compilation. This is a significant security 
improvement, but it's not enough for only one individual to build something deterministically
as they could be compromised - the real guarantee comes from multiple individuals 
compiling the software using different setups and still getting the same hashes. This 
gives us multiple points of reference, which we can use to figure out if the integrity 
of the software is truly in tact.

To develop a further intuition about the distinction between trusting source code
and trusting what the compiler translates that source code to, you may refer to the
seminal paper by Ken Thomson, [Reflections on Trusting Trust](https://www.cs.cmu.edu/~rdriley/487/papers/Thompson_1984_ReflectionsonTrustingTrust.pdf)

## Comparison

A comparison of `stagex` to other distros in some of the areas we care about:

| Distro | Containerized | Signatures | Libc  | Bootstrapped | Reproducible | Rust Deps |
|--------|---------------|------------|-------|--------------|--------------|-----------|
| Stagex | Native        | 2+ Human   | Musl  | Yes          | Yes          | 4         |
| Guix   | No            | 1 Human    | Glibc | Yes          | Yes          | 4         |
| Nix    | No            | 1 Bot      | Glibc | Partial      | Mostly       | 4         |
| Debian | Adapted       | 1 Human    | Glibc | No           | Partial      | 232       |
| Arch   | Adapted       | 1 Human    | Glibc | No           | Partial      | 262       |
| Fedora | Adapted       | 1 Bot      | Glibc | No           | No           | 166       |
| Alpine | Adapted       | None       | Musl  | No           | No           | 32        |

### Notes

- “Bootstrapped”: Can the entire distro be full-source-bootstrapped from Stage0
- “Reproducible”: Is the entire distro reproducible bit-for-bit identically
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
    * Maintain a [keyoxide](https://keyoxide.org) profile self-certifying keys
    * Maintain a [Hagrid](https://keys.openpgp.org) profile with verified UIDs
    * Make best efforts to meet in person and sign each others keys
    * Create signatures from highly trusted operating systems
        * E.g Dedicated QubesOS VM, or a an airgapped signing system

### Reproducibility

The only way to produce trustworthy packages is to make sure no single system
or human is ever trusted in the process of compiling them. Everything we
release must be built deterministically. Further to avoid trusting any specific
distro or platform, we must be able to reproduce even from wildly different
toolchains, architectures, kernels, etc.

Using OCI container images as our base packaging system helps a lot here by
making it easy to throw away non-deterministic build stages and control many
aspects of the build environment. Also, as a well documented spec, it allows
our packages to (ideally) be built with totally different OCI toolchains such
as Docker, Podman, Kaniko, or Buildah.

This is only part of the story though, because being able to build
deterministically means the compilers that compile our code themselves must
be [bootstrapped](https://en.wikipedia.org/wiki/Bootstrapping_(compilers)) all the way from source code in a deterministic way.

* Final distributable packages are always OCI container images
    * OCI allows reproduction by totally different toolchains
        E.g: Docker, Podman, Kaniko, or Buildah.
    * OCI allows unlimited signatures on builds as part of the spec
      * E.g: each party that chooses to reproduce adds their own signature
* We always "Full Source Bootstrap" everything from 0
    * [Stage0](packages/stage0/Containerfile): 387 bytes of x86 assembly built by 3 distros with the same hash
        * Also the same hash many others get from wildly different toolchains
        * Relevant: [Guix: Building From Source All The Way Down](https://guix.gnu.org/en/blog/2023/the-full-source-bootstrap-building-from-source-all-the-way-down/)
    * [Stage1](packages/stage1/Containerfile): A full x86 toolchain built from stage0 via [live-bootstrap](https://github.com/fosslinux/live-bootstrap/blob/master/parts.rst)
    * [Stage2](packages/stage2/Containerfile): Cross toolchain bridging us to modern 64 bit architectures
    * [Stage3](packages/stage3/Containerfile): Native toolchain in native 64 bit architecture
    * [Stage(x)](.): Later stages build the distributed packages in this repo

For further reading see the [Bootstrappable Builds](https://bootstrappable.org/) Project.

## Building

### Requirements

* An OCI building runtime
    * Currently Docker supported (v25+)
        * [`containerd` support](https://docs.docker.com/engine/storage/containerd/#enable-containerd-image-store-on-docker-engine) is required
    * Support for buildah and podman coming soon
	
* Gnu Make

### Examples

#### Reproduce entire tree

```shell
make
```

#### Compile specific package

```shell
make rust
```

#### Compile specific package without cache

```shell
make NOCACHE=1
```

#### Sign all locally built packages (WIP)

Do this after successfully reproducing all packages and stages:

```shell
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
