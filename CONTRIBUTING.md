# Contributing to Stagex

We'd be happy to have you join the community!
Below are the steps and processes that we follow.

This document uses [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119.html), and 
[RFC 6919](https://www.rfc-editor.org/rfc/rfc6919.html).

## Topics

* [Reporting Issues](#reporting-issues)
* [Working On Issues](#working-on-issues)
* [Contributing to Stagex as package maintainer](#contributing-to-stagex-as-package-maintainer)
* [Helpful one liners](#helpful-one-liners)
* [Commits](#commits)
* [Submitting Pull Requests](#submitting-pull-requests)
* [Communications](#communications)

## Reporting Issues

Before reporting an issue, check our backlog of
[open issues](https://codeberg.org/stagex/stagex/issues)
to see if someone else has already reported it. If so, feel free to add
your scenario, or additional information, to the discussion or simply
"subscribe" to it to be notified when it is updated.
If you find a new issue with the project we'd love to hear about it!
The most important aspect of a bug report is that it includes enough information for
us to reproduce it.
Please don't include any private/sensitive information in your issue!

## Working On Issues

Once you have decided to contribute to Stagex by working on an issue, check our
backlog of [open issues](https://codeberg.org/stagex/stagex/issues) looking
for any that do not have an "In Progress" label attached to it.  Often issues
will be assigned to someone, to be worked on at a later time.

## Contributing to Stagex as package maintainer

This section describes how to start a contribution to Stagex.

### Fork and clone Stagex

First you need to fork this project on Codeberg.
Then clone your fork locally:

```shell
git clone git@codeberg.org:<you>/stagex 
cd  stagex
```

### Prepare your environment

The script below sets up required dependencies for Debian but can also be used
as a reference for figuring out what needs to be set up on other Linux 
distributions:
```shell
sh ./src/setup-debian-12.sh
```

### Building 

Stagex uses a Makefile to build everything.

Populate your local registry by building from scratch

```shell
make all
```

|
OR
|
Prepopulate your docker local registry

```shell
make preseed 
```

### Packaging

Find if there is a relevant package that you can use as a boilerplate for the
new addition.

```sh
cp -R packages/core/python packages/user/cython
vim packages/user/cython/Containerfile
# fix SRC_FILE, SRC_HASH, SRC_URL etc manually
# incorporate anything relevant from Alpine's build(){ block }  for {package} 
# https://git.alpinelinux.org/aports/tree/main/cython/APKBUILD
vim packages/user/cython/package.toml
# update the name of the package, source url, hash, version etc.
make user-cython
```

### Standards for packages

Refer to the [packaging standards](MAINTENANCE.md#packaging-standards)

## Helpful one liners

### See contents of a package:

```sh
make content-<package-name>
```

### Test package for reproducibility:

```sh
mkdir out2;
package=somepackage; rm -rf out{,2}/${package}; make NOCACHE=1 ${package}; mv out/${package} out2/${package}; make NOCACHE=1 ${package}; diffoscope $(find out*/${package} -type f -printf '%s %p\n' | sort -nr | head -n2 | awk '{ print $2 }' | tr '\n' ' ')
```

### Make svg graph of dependency tree for a single package

```sh
package=somepackage; make -Bnd ${package} | make2graph | dot -Tsvg -o ${package}-graph.svg
```

### Build and import image into OCI image store

```sh
make IMPORT=1 <package-name>
```

### Import image into OCI store 

```sh
make import-<package-name>
```

## Commits 

- **Formatting:** [Conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) standard
is preferred for commit formatting.

- **Signing:** Commits must be signed (PGP or SSH), preferably by a well known key. 
[Keyoxide](https://keyoxide.org) profiles are appreciated.

- **Logical Commits:** Commits should handle a single use-case. e.g. adding a 
single new package, fixing formatting, moving a package and it's dependencies 
to a different stage (core, user, pallet, etc.)

- **Key management:** Management of keys in trusted environments, such as via 
hardware-based virtualization, or in air-gapped environments and usage of 
smart cards are highly encouraged.

- You can set up your local git signing config using the following commands:
    ```
    $ git config --global user.name <name>
    $ git config --global user.email <email>
    $ git config --global user.signingKey <pgp_key_id>
    $ git config --global commit.gpgsign true
    $ git config --global commit.merge true
    ```

## Submitting Pull Requests

- **No issue required:** It's fine to open a PR directly without a 
corresponding issue, as long as you clearly explain the problem and how to 
reproduce it.

- **Describe the problem:** Whether it's a one-line fix or a major feature, 
always explain the underlying problem that motivated the change.

- **New features:** Describe the use cases the new code is meant to address.

- **Break up large PRs:** When possible, split big changes into smaller, 
self-contained PRs to make them easier to review — but only if each part makes 
sense on its own.

- **Close syntax:** PRs that fix issues should include a reference like `Closes #x` in the
commit message so that Codeberg will automatically close the referenced issue
when the PR is merged.

A [maintainer](MAINTAINERS) will "adopt" your PR by creating an empty commit on 
your branch to attest they reviewed the proposed changes, and as such has to be 
the last commit added to the branch at the time of merging.

## Communications

For general questions and discussion, please use the
[matrix://#stagex:matrix.org](https://matrix.to/#/#stagex:matrix.org) | [ircs://irc.oftc.net:6697#stagex](https://webchat.oftc.net/?channels=stagex&uio=MT11bmRlZmluZWQmMTE9MTk14d)

For discussions around issues/bugs and features, you can use Codeberg
[issues](https://codeberg.org/stagex/stagex/issues)
and
[PRs](https://codeberg.org/stagex/stagex/pulls)
tracking system.
