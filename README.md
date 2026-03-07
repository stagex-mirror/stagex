# \[Stageˣ\]

[git://codeberg.org:stagex/stagex](https://codeberg.org/stagex/stagex) | [matrix://#stagex:matrix.org](https://matrix.to/#/#stagex:matrix.org) | [ircs://irc.oftc.net:6697#stagex](https://webchat.oftc.net/?channels=stagex&uio=MT11bmRlZmluZWQmMTE9MTk14d)

[![Donate to StageX's OpenCollective](https://opencollective.com/stagex/donate/button.png?color=white)](https://opencollective.com/stagex/donate)

---

Minimalism and security first repository of reproducible and multi-signed OCI
images of common open source software toolchains full-source bootstrapped from
Stage 0 all the way up.

If you want to build or deploy software on a foundation of minimalism and
determinism with reasonable security, StageX might be the solution you are
looking for.

## Table of Contents

* [Usage](#usage)
  * [Examples](#examples)
  * [Package Management Policies](#package-management-policies)
* [Goals](#goals)
  * [Full-Source Bootstrapping](#full-source-bootstrapping)
  * [Reproducibility](#reproducibility)
  * [Cryptographic Accountability](#cryptographic-accountability)
  * [Quorum Artifact Signing](#quorum-artifact-signing)
  * [Minimalism](#minimalism)
* [Background](#background)
* [Comparison](#comparison)
  * [Notes](#notes)
  * [Signatures](#signatures)
  * [Reproducibility](#reproducibility)
* [Building](#building)
  * [Requirements](#requirements)
  * [Examples](#examples-1)
* [Examples](#examples-2)
* [Resources](#resources)
* [References](#references)
* [Sponsors](#sponsors)
* [Code of Conduct](CODE_OF_CONDUCT.md)
* [Contributing](CONTRIBUTING.md)
* [Maintainer Guidelines](MAINTENANCE.md)
* [LICENSE](LICENSE)


## Usage

You can do anything with these images you would with almost any other musl based
containerized Linux distro, only with high supply chain integrity and
determinism.

For a full list of images see the "packages" directory or check our [website](https://stagex.tools/packages/)

### Examples

#### Get a shell in our x86_64 Stage3 bootstrap image

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

Unlike most Linux distros, StageX adopts an OCI-first design: Open Container
Initiative (OCI) images are the native packaging system, not just a
distribution format. This means system components are immutable, pre-built
container images that are constructed, signed, and verified outside the runtime
environment. During installation, no arbitrary scripts are run. Image
verification and unpacking are the primary operations, significantly reducing
the attack surface.

StageX ships no first-party code at all. We just package things in the most
"stock" way possible, with exceptions only to maintain determinism.

Every image is "from scratch" and contains an empty filesystem with the
installed package. Because StageX images comply with OCI specifications, they
run without modification across Docker, Podman, containerd, and any other
compliant runtime, reducing single points of failure in the runtime layer.
Distribution is handled through established tooling (skopeo, oras) with
built-in support for security hardening, sandboxing, and provenance tracking.
Immutable images facilitate atomic upgrades and rollbacks, enhancing
operational stability.

By default you always get the latest updates to dependencies on the fly, but
you retain the option for bit-for-bit reproducible builds by locking any given
dependency at a particular tag or image hash.

If you want an old version of rust with a recent version of clang to work around
some problem build, you can do that without resorting to low security
"curl | bash" style solutions like rustup.

## Goals

We built StageX to satisfy high-assurance threat models where trusting any
single system or maintainer in the software supply chain cannot be tolerated.
Our design enforces strict verifiability across five core criteria, making
StageX the first Linux distribution to integrate all of the following into a
unified, self-consistent model. See our
[whitepaper](https://codeberg.org/stagex/whitepapers/src/branch/main/out/stagex.pdf)
for the formal analysis.

### Full-Source Bootstrapping

* The entire toolchain is bootstrappable from source, starting from a 181-byte
  Stage0 machine code seed that any programmer can audit by hand
* No pre-compiled binaries are used at any build stage
* Each bootstrap stage (Stage0 → Stage1 → Stage2 → Stage3 → StageX) is
  deterministic and independently verifiable
* Any software that lacks a bootstrap path from source (e.g., Haskell, Ada) are
  excluded by policy until one exists

### Reproducibility

* Every package must build deterministically; non-reproducible software is
  rejected
* Builds are hermetic (hash-locked inputs, no network access), deterministic
  (bit-for-bit identical output), and reproducible (portable across different
  systems and hardware)
* Reproducibility is verified by building on at least two different CPU vendors
  (e.g., AMD and Intel) before release
* OCI container images enable reproduction by totally different toolchains
  (Docker, Podman, Kaniko, Buildah)

### Cryptographic Accountability

* Every code change must be reviewed and signed off by at least two maintainers
* A single maintainer merging a non-maintainer's code, even with a signed
  commit, is insufficient
* All commits are signed (PGP or SSH) with keys backed by
  [Keyoxide](https://keyoxide.org) and [Hagrid](https://keys.openpgp.org)
  profiles
* Signing keys are maintained offline or on hardware security modules
  (YubiKey, NitroKey, Split GPG via QubesOS)

### Quorum Artifact Signing

* No artifact is considered trusted until at least two independent maintainers
  rebuild and verify it. Only then is it co-signed using PGP signatures
* This guarantees a 1-to-1 mapping between source and binary, enforced
  *before* distribution rather than audited after the fact
* Signatures use the [Container Signature Format](https://github.com/containers/image/blob/main/docs/containers-signature.5.md)
  and are committed to the repository as the source of truth
* As far as we can tell, no other distribution requires multi-party
  reproduction proofs for every released artifact

### Minimalism

* Based on musl libc by default, with glibc also supported for GNU system
  compatibility
  * musl: ~1/4 the code of glibc, easier to audit, consistent cross-platform
    behavior
  * mimalloc (by Microsoft Research) used as default allocator to address
    musl's multi-threaded performance limitations
* LLVM/Clang toolchain by default rather than GCC
  * Clang functions as a native cross-compiler, so a single installation can
    emit code for x86_64, aarch64, and other architectures
  * Reduces maintenance burden and attack surface vs. per-target GCC builds
* Package using tools you already have
  * OCI build tool of choice (Docker, Buildah, Podman)
  * Make (for dependency management)
  * Prove hashes of bootstrap layer builds match before proceeding
* All images are built FROM scratch containing only the installed package,
  no base distribution bloat
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
on all of these basic tenets of supply chain security. StageX is an attempt to fix
this, in order to satisfy the criteria of reasonably secure supply chain strategy,
which requires more than one individual to deterministically build and sign software.

Ask yourself the following: do I have a way of verifying that this binary was
produced based on this source code?

While software is often reviewed for security flaws, and sometimes provides signed
releases, what is missing is the ability to prove that the resulting binary is the
direct result of that code and nothing has been modified along the way. To achieve
this, we have to make the software always build the exact same thing, down to the
last bit. More precisely, we distinguish three properties: a build is *hermetic*
if its inputs are hash-locked with no network access or external influences; it
is *deterministic* if it always produces bit-for-bit identical output; and it is
*reproducible* if it can produce deterministic artifacts across different systems
and hardware. You may be reading this and thinking "of course it should always build
to the same exact binary", but this is usually not the case - it's highly unlikely
that any of the software you have ever built is deterministic.
By forcing software to always produce the same binary, we
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

A comparison of StageX to other distros in some of the areas we care about:

| Distribution | Signers | OCI       | Language        | Bootstrapped | Reproducible | Toolchain | C Library | Allocator    |
|--------------|---------|-----------|-----------------|--------------|--------------|-----------|-----------|--------------|
| **StageX**   | **2**   | **Native** | **Containerfile** | **Yes**  | **Yes**      | **LLVM**  | **musl**  | **mimalloc** |
| Guix         | 1       | Exported  | Custom          | Yes          | Mostly       | GNU       | glibc     | glibc        |
| Arch         | 1       | Published | Shell           | No           | Mostly       | GNU       | glibc     | glibc        |
| Debian       | 1       | Published | Custom          | No           | Mostly       | GNU       | glibc     | glibc        |
| Alpine       | 1       | Published | Shell           | No           | No           | GNU       | musl      | mallocng     |
| NixOS        | 0       | Exported  | Custom          | Partial      | Mostly       | GNU       | glibc     | glibc        |
| Buildroot    | 0       | Exported  | Makefile        | No           | No           | GNU       | glibc     | glibc        |
| Chimera      | 0       | Published | Python          | No           | No           | LLVM      | musl      | mimalloc     |
| Wolfi        | 0       | Native    | YAML            | Partial      | No           | GNU       | glibc     | glibc        |
| Yocto        | 0       | Exported  | Custom          | No           | No           | GNU       | glibc     | glibc        |

### Notes

Table is ordered by objective supply chain security metrics: “Signers”,
“Bootstrapped”, and “Reproducible”.

* “Signers”
  * The minimum number of human signers required to make changes to the
    distribution. Keys controlled by machines or signers controlled by multiple
    individuals do not count as a signer.
* “OCI”
  * “Native”: OCI layers are the native package management system
  * “Exported”: Has the capability to export OCI from non-OCI build system
  * “Published”: Has published official OCI images
* “Bootstrapped”
  * Can the entire distro be full-source-bootstrapped from Stage0
* “Reproducible”
  * Is the entire distro reproduced bit-for-bit identically for every release

### Signatures

* Signatures are made by the PGP public keys in the "keys" directory
* Signatures are made by any tool that implements "[Container Signature Format](https://github.com/containers/image/blob/main/docs/containers-signature.5.md)"
  * We provide a minimal shell script implementation as a convenience
  * Podman also [implements support](https://github.com/containers/podman/blob/main/docs/tutorials/image_signing.md) for this signature scheme
* Signatures are "PR"ed and committed to the [signatures repo](https://codeberg.org/stagex/signatures) as a source of truth and they're made available via an HTTPS endpoint for as a lookaside.
* Signatures can be mirrored to any HTTPS url
* Container daemons can verify signatures on pull with a [containers-policy.json](https://github.com/containers/image/blob/main/docs/containers-policy.json.5.md)
* As a policy, we expect all published signers to:
  * Maintain their PGP private keys offline and/or on personal HSMs
    * E.g. Nitrokey, Yubikey, Ledger, Trezor, etc.
  * Maintain a [Keyoxide](https://keyoxide.org) profile self-certifying keys
  * Maintain a [Hagrid](https://keys.openpgp.org) profile with verified UIDs
  * Make best efforts to meet in person and sign each others' keys
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
      * E.g: Docker, Podman, Kaniko, or Buildah.
  * OCI allows unlimited signatures on builds as part of the spec
    * E.g: each party that chooses to reproduce adds their own signature
* We always "Full Source Bootstrap" everything from 0
  * [Stage0](packages/bootstrap/stage0/Containerfile): 181 bytes of x86 machine code, a concrete trust anchor small enough for any programmer to audit by hand
    * Reproduced with the same hash across multiple distros and wildly different toolchains
      * Relevant: [Guix: Building From Source All The Way Down](https://guix.gnu.org/en/blog/2023/the-full-source-bootstrap-building-from-source-all-the-way-down/)
  * [Stage1](packages/bootstrap/stage1/Containerfile): A primitive C toolchain built from Stage0 via [live-bootstrap](https://github.com/fosslinux/live-bootstrap/blob/master/parts.rst)
  * [Stage2](packages/bootstrap/stage2/Containerfile): Cross-compiler toolchain bridging to modern 64-bit architectures
  * [Stage3](packages/bootstrap/stage3/Containerfile): Final modern C toolchain in native 64-bit architecture
  * [Stage(x)](.): Later stages build the distributed packages in this repo

For further reading, see the [Bootstrappable Builds](https://bootstrappable.org/) Project.

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

## Examples

* [Sui Blockchain Fullnode](https://github.com/MystenLabs/sui/blob/main/docker/sui-node-deterministic/Dockerfile)
  * Large rust application w/ C dependencies
* [Nimiq Blockchain Protocol](https://github.com/nimiq/core-rs-albatross/blob/albatross/build/Containerfile)
  * Large rust application implementing all supporting software for the Nimiq blockchain protocol
* [QuorumOS](https://github.com/tkhq/qos/tree/main/src/images)
  * Nitro Enclave Framework w/ minimal rust init system and support applications
* [EnclaveOS](https://git.distrust.co/public/enclaveos)
  * Mininmal Nitro Enclave Hello World
* [AirgapOS](https://git.distrust.co/public/airgap)
  * Standalone minimal bootable Linux ISO for workstations
* [ReproOS](https://codeberg.org/stagex/repros)
  * Server Linux image w/ minimal hypervisor guest image

## Resources

### Blogs

* [Reproducible builds made easy: introducing StageX](https://quorum.tkhq.xyz/posts/reproducible-builds-made-easy-introducing-stagex/)
  * Arnaud Brousseau | 2024
* [Remote attestations are useless without reproducible builds](https://quorum.tkhq.xyz/posts/remote-attestations-useless-without-reproducible-builds/)
  * Arnaud Brousseau | 2024

### Organizations

* [Bootstrappable Builds Project](https://bootstrappable.org)
* [Reproducible Builds Project](https://reproducible-builds.org)
* [SLSA Framework](https://slsa.dev)

### Alternatives

* [Bitcoin Optech: Reproducible Builds](https://bitcoinops.org/en/topics/reproducible-builds/)
* [Arch Linux: Reproducible Builds](https://wiki.archlinux.org/title/Reproducible_builds)
* [NixOS: Reproducible Builds](https://reproducible.nixos.org/)
* [Guix: Reproducible Builds](https://qa.guix.gnu.org/reproducible-builds)
* [Debian: Reproducible Builds](https://wiki.debian.org/ReproducibleBuilds)

## References

### Academic

* [StageX: Eliminating Single Points of Failure in Linux Distributions](https://codeberg.org/stagex/whitepapers/src/branch/main/out/stagex.pdf)
  * Anton D. Livaja, Lance R. Vick, Ryan Heywood, Daniel R. Grove | March 2026

* [SoK: Analysis of Software Supply Chain Security by Establishing Secure Design Properties](https://arxiv.org/abs/2406.10109)
  * Chinenye Okafor, Taylor R. Schorlemmer, Santiago Torres-Arias, James C. Davis | June 2024
* [A Review of Attacks Against Language-Based Package Managers](https://arxiv.org/abs/2302.08959)
  * Aarnav M. Bos | February 2023
* [Software supply chain: review of attacks, risk assessment strategies and security controls](https://arxiv.org/abs/2305.14157)
  * Betul Gokkaya, Leonardo Aniello, Basel Halak | May 2023
* [Enhancing Software Supply Chain Resilience: Strategy For Mitigating Software Supply Chain Security Risks And Ensuring Security Continuity In Development Lifecycle](https://arxiv.org/abs/2407.13785)
  * Ahmed Akinsola, Abdullah Akinde | July 2024
* [What is Software Supply Chain Security](https://arxiv.org/abs/2209.04006)
  * Marcela S. Melara and Mic Bowman | September 2022
* [An Industry Interview Study of Software Signing for Supply Chain Security](
https://arxiv.org/abs/2406.08198)
  * Kelechi G. Kalu, Tanya Singla, Chinenye Okafor, Santiago Torres-Arias, James C. Davis | June 2024
* [Journey to the Center of Software Supply Chain Attacks](https://arxiv.org/abs/2304.05200)
  * Piergiorgio Ladisa, Serena Elisa Ponta, Antonino Sabetta, Matias Martinez, Olivier Barais | April 2023
* [SoK: A Defense-Oriented Evaluation of Software Supply Chain Security](https://arxiv.org/abs/2405.14993)
  * Eman Abu Ishgair, Marcela S. Melara, Santiago Torres-Arias | May 2024
* [S3C2 Summit 2023-02: Industry Secure Supply Chain Summit](https://arxiv.org/abs/2307.16557)
  * Trevor Dunlap, Yasemin Acar, Michel Cucker, William Enck, Alexandros Kapravelos, Christian Kastner, Laurie Williams | July 2023
* [An Integrity-Focused Threat Model for Software Development Pipelines](https://arxiv.org/abs/2211.06249)
  * B. M. Reichert (1) and R. R. Obelheiro (1) ((1) Graduate Program in Applied Computing, State University of Santa Catarina) | November 2022
* [Dirty-Waters: Detecting Software Supply Chain Smells](https://arxiv.org/abs/2410.16049)
  * Raphina Liu, Sofia Bobadilla, Benoit Baudry, Martin Monperrus | October 2024
* [A Systematic Literature Review on Trust in the Software Ecosystem](https://arxiv.org/abs/2203.05678)
  * Fang Hou, Slinger Jansen | March 2022
* [Backstabber's Knife Collection: A Review of Open Source Software Supply Chain Attacks](https://arxiv.org/abs/2005.09535)
  * Marc Ohm, Henrik Plate, Arnold Sykosch, Michael Meier | May 2020
* [Reproducible Builds: Increasing the Integrity of Software Supply Chains](
https://arxiv.org/abs/2104.06020)
  * Chris Lamb, Stefano Zacchiroli (DGD-I, UP) | April 2021
* [Reproducibility of Build Environments through Space and Time](https://arxiv.org/abs/2402.00424)
  * Julien Malka (IP Paris, LTCI, ACES), Stefano Zacchiroli (IP Paris, LTCI, ACES), Th'eo Zimmermann (ACES, INFRES, IP Paris) | February 2024
* [Levels of Binary Equivalence for the Comparison of Binaries from Alternative Builds](https://arxiv.org/abs/2410.08427)
  * Jens Dietrich, Tim White, Behnaz Hassanshahi, Paddy Krishnan | October 2024
* [Repro: An Open-Source Library for Improving the Reproducibility and Usability of Publicly Available Research Code](https://arxiv.org/abs/2204.13848)
  * Daniel Deutsch and Dan Roth | April 2022
* [Reproducible and User-Controlled Software Environments in HPC with Guix](
https://arxiv.org/abs/1506.02822)
  * Ludovic Court`es (INRIA Bordeaux - Sud-Ouest), Ricardo Wurmus | June 2015
* [Reflections on trusting trust](https://dl.acm.org/doi/10.1145/358198.358210)
  * Ken Thompson | 1984

### Blogs

* [The Full-Source Bootstrap: Building from source all the way down](https://guix.gnu.org/en/blog/2023/the-full-source-bootstrap-building-from-source-all-the-way-down/)
  * Janneke Nieuwenhuizen, Ludovic Courtès | 2023

### Presentations

* [Breaking Bitcoin: The Bitcoin Build System](https://diyhpl.us/wiki/transcripts/breaking-bitcoin/2019/bitcoin-build-system/)
  * Carl Dong | 2020
* [Expanding (Dis)trust](https://antonlivaja.com/videos/2024-incyber-stagex-talk.mp4)
  * Anton Livaja | 2024

## Sponsors

* [Caution SECZ](https://caution.co)
* [DR Grove Software LLC](https://drgrovellc.com)
* [Distrust](https://distrust.co)
* [Mysten Labs](https://mystenlabs.com)
* [Turnkey](https://turnkey.com)
