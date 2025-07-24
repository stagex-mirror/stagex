# Maintainer Guidelines

This document uses [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119.html), and 
[RFC 6919](https://www.rfc-editor.org/rfc/rfc6919.html).


## PGP Key Management

StageX maintainers are required to manage signing keys according to following
directives:

* MUST never expose private key material to an internet connected environment.

* MUST use high quality smart cards for management of keys such as YubiKey 
series 5 or NitroKey 3 OR Split GPG qubes setup.

* MUST enable PIN protection using a non-default password (both for user and 
admin pins) when using smart cards.

* MUST enable option to require *touch* for all PGP operations; or in the case
of Split GPG on qubes, must require interaction for all PGP operations. 

## Packaging Standards

All software added to StageX has to follow theses guidelines:

- MUST be reviewed for malicious code.

- MUST verify source URLs are legitimate and auditable.

- MUST verify pre-compiled binaries are NOT used during build.

- MUST verify software is bit-for-bit reproducible.

- MUST be free of known significant vulnerabilities for the version used.

## Pull Requests

Pull requests for every change **MUST** follow the given flow:

`pull-request-branch -> staging -> current-release-branch -> staging -> main`

Making a commit short-cut the staging or the release branch **removes the ability
to track who approves contributions and when those contributions has been
approved**. 

If a patch is necessary for a release, it **MUST** flow from a PR, to staging, to 
the release branch. The release branch should not contain any changes (ignoring 
`digests.txt` and signatures) that do not exist in `staging`.

Pull requests **MUST** be merged using a **signed merge commit**. To configure your
Git porcelain to always use merge commits, run: 

```sh
git config merge.ff false
```
To configure your Git porcelain to always sign commits, run:

```sh
git config commit.gpgsign true
```

## Release Branches

Release branches take the format `release/YYYY.MM.<release-revision>`. A release **MUST** include a
PR to staging to introduce a bump to `digests.txt`, creating the release
branch. Once the branch is created, other maintainers **MAY** begin reproducing.
The release engineer should run `make sign` to ensure a signature exists for
every package included in the release.

In the Git forge UI, the release pull request **MUST** target the `main` branch,
to provide a summary of all changes since the latest release.

Any commits required once the branch is created, but before the release is
published, **MUST** flow from a PR (if push access to the release branch is not
given) to staging, where the release branch can then rebase on staging.

Once a release is published, the release branch **MUST** perform a signed merge
commit into staging, followed by a signed merge commit from staging to main.
Any further pull requests to the branch after the series of releases is done
(which may be published after release, if strictly necessary) **SHOULD** target 
the release branch, and the release branch will live on its own.

## Build Artifact Signing

Signing release build artifacts signifies a maintainer has confirmed that all
package hashes match another maintainers and either personally reviewed all new
code changes or has observed signed evidence that at least two maintainers have 
reviewed all code changes.

## PR Adoption / Non-maintainer contributions

If a non-maintainer opens a pull request, an existing StageX maintainer must 
explicitly adopt it by reviewing the changes for compliance with project 
[packaging standards](##packaging-standards).

To ensure long-term integrity and scalability, every change must be reviewed 
and signed off by at least two maintainers. A single maintainer merging a 
non-maintainer's code—even with a signed commit—is insufficient, as it does not 
meet the multi-party verification policy.

After completing the review, the adopting maintainer **MUST** create a final 
empty, signed commit to signal that the changes have passed review. This commit 
**MUST** be the last commit in the branch prior to merge into staging:

```sh
git commit --allow-empty -m "Adopt"
```

This process creates a clear, cryptographically verifiable audit trail for 
every code change, and ensures that StageX remains scalable and secure as 
package volume increases.

[This](https://codeberg.org/stagex/stagex/pulls/519) is an example what an 
adopted PR looks like.

### Adopting PRs from forked repos

When someone forks a repository, the following steps are required to adopt the PR:

1. Add the new remote if you don't have it locally:
```sh
git add remote <new-remote-name> http://<...>
```

2. Fetch the branches
```sh
git fetch <new-remote-name> -a
```

3. Create a new branch based on the one from the forked repo
```sh
git checkout -b <new-remote-name>/<remote-branch-name> <new-remote-name>/<remote-branch-name>
```

4. Add "adopt" commit
```sh
git commit --allow-empty -m "Adopt"
```
