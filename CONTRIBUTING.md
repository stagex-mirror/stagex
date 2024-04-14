![[Stage<sup>x</sup>]](https://codeberg.org/repo-avatars/02eca12ad01b1b867ca7708117645b4d9791a7f7a30abd6d8e1dc20900f7b0d7)
# Contributing to Stagex 

We'd be happy to have you join the community! 
Below are the steps and processes that we follow.

## Topics

* [Reporting Issues](#reporting-issues)
* [Working On Issues](#working-on-issues)
* [Contributing to Stagex as package maintainer](#contributing-to-stagex-as-package-maintainer)
* [Helpful one liners](#helpful-one-liners)
* [Submitting Pull Requests](#submitting-pull-requests)
* [Communications](#communications)

## Reporting Issues

Before reporting an issue, check our backlog of
[open issues](https://codeberg.org/stagex/stagex/issues)
to see if someone else has already reported it. If so, feel free to add
your scenario, or additional information, to the discussion. Or simply
"subscribe" to it to be notified when it is updated.
If you find a new issue with the project we'd love to hear about it! The most
important aspect of a bug report is that it includes enough information for
us to reproduce it. 
Please don't include any private/sensitive information in your issue!

## Working On Issues

Once you have decided to contribute to Stagex by working on an issue, check our
backlog of [open issues](https://codeberg.org/stagex/stagex/issues) looking
for any that do not have an "In Progress" label attached to it.  Often issues
will be assigned to someone, to be worked on at a later time.

## Contributing to Stagex as package maintainer 

This section describes how to start a contribution to Stagex. 
These instructions are geared towards using a Linux development machine,
preferably Debian, which is required for setting up your development tools.

### Fork and clone Stagex 

First you need to fork this project on Codeberg.
Then clone your fork locally:
```shell
$ git clone git@codeberg.com:<you>/stagex 
$ cd  stagex
```

### Prepare your environment
```
$ sh ./src/setup-debian-12.sh
```

### Deal with make

Stagex uses a Makefile to build everything.

Populate your local registry by building from scratch
```shell
$ make all
```
|
OR
|
Prepopulate your local registry
```shell
$ make preseed 
$ rm -rf ./out/sxctl
$ make sxctl
```

Find if there is a relevant package that you can use as a boilerplate for the 
new addition.
```sh
cp -R packages/python packages/cython
vim packages/cython/Containerfile
# fix SRC_FILE, SRC_HASH, SRC_URL etc manually
# incorporate anything relevant from Alpines build(){ block }  for {package} 
# https://git.alpinelinux.org/aports/tree/main/cython/APKBUILD
make gen-make
make cython
make digests 
```

Then you can commit {signed} and push your package and open a PR.
IMPORTANT: the PR should be just the `Containerfile`, and the added block for
the package you are contributing in `packages.mk`

## Helpful one liners
<--author: Lance R. Vick -->

- see contents of a package:
```sh
package=somepackage tar -tvf $(find out/${package} -type f -printf '%s %p\n' | sort -nr | head -n1 | awk '{ print $2 }') | less
```

- test package for reproducibility:
```sh
package=somepackage; rm -rf out{,2}/${package}; make NOCACHE=1 ${package}; mv out/${package} out2/; make NOCACHE=1 ${package}; diffoscope $(find out*/${package} -type f -printf '%s %p\n' | sort -nr | head -n2 | awk '{ print $2 }' | tr '\n' ' ')
```

- make svg graph of dependency tree for a single package
```sh
package=somepackage; make -Bnd ${package} | make2graph | dot -Tsvg -o ${package}-graph.svg
```
<--author: Lance R. Vick -->

## Submitting Pull Requests

No Pull Request (PR) is too small! Typos, additional comments in the code,
new test cases, bug fixes, new features, more documentation, ... it's all
welcome!

While bug fixes can first be identified via an "issue", that is not required.
It's ok to just open up a PR with the fix, but make sure you include the same
information you would have included in an issue - like how to reproduce it.

PRs for new features should include some background on what use cases the
new code is trying to address. When possible and when it makes sense, try to break-up
larger PRs into smaller ones - it's easier to review smaller
code changes. But only if those smaller ones make sense as stand-alone PRs.

Regardless of the type of PR, all PRs should include:
* well documented code changes.

PRs that fix issues should include a reference like `Closes #XXXX` in the
commit message so that Codeberg will automatically close the referenced issue
when the PR is merged.

PRs will be approved by a [maintainer] listed in [`MAINTAINERS`](MAINTAINERS).

In case you're only changing docs, make sure to prefix the PR title with
"[CI:DOCS]". 

### Describe your Changes in Commit Messages

Describe your problem. Whether your patch is a one-line bug fix or 5000 lines
of a new feature, there must be an underlying problem that motivated you to do
this work. Convince the reviewer that there is a problem worth fixing and that
it makes sense for them to read past the first paragraph.

Describe user-visible impact. Straight up crashes and lockups are pretty
convincing, but not all bugs are that blatant. Even if the problem was spotted
during code review, describe the impact you think it can have on users. Keep in
mind that the majority of users run packages provided by distributions, so
include anything that could help route your change downstream.

### Sign your commits

Your signature certifies that you wrote the patch or otherwise have the right to pass
it on as an open-source patch.

If you set your `user.name` and `user.email` git configs, you can sign your
commit automatically with `git commit -s`.


## Communications

For general questions and discussion, please use the
[matrix://#stagex:matrix.org](https://matrix.to/#/#stagex:matrix.org) | [ircs://irc.oftc.net:6697#stagex](https://webchat.oftc.net/?channels=stagex&uio=MT11bmRlZmluZWQmMTE9MTk14d)

For discussions around issues/bugs and features, you can use Codeberg 
[issues](https://codeberg.org/stagex/stagex/issues)
and
[PRs](https://codeberg.org/stagex/stagex/pulls)
tracking system.

