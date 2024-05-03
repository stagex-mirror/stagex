## Pull Requests

Pull requests for every change should follow the given flow:
`pull-request-branch -> staging -> current-release-branch -> staging -> main`.
Making a commit short-cut the staging or the release branch removes the ability
to track who approves contributions and when those contributions has been
approved. If a patch is necessary for a release, it should flow from a PR, to
staging, to the release branch. The release branch should not contain any
changes (ignoring `digests.txt` and signatures) that do not exist in `staging`.

Pull requests should be merged using a signed merge commit. To configure your
Git porcelain to always use merge commits, run `git config merge.ff false`. To
configure your Git porcelain to always sign commits, run `git config
commit.gpgsign true`.

## Release Branches

Release branches take the format `YYYY.MM.release`. A release should include a
PR to staging to introduce a bump to `digests.txt`, creating the release
branch. Once the branch is created, other maintainers should begin reproducing.
The release engineer should run `make sign` to ensure a signature exists for
every package included in the release.

In the Git forge UI, the release pull request should target the `main` branch,
to provide a summary of all changes since the latest release.

Any commits required once the branch is created, but before the release is
published, should flow from a PR (if push access to the release branch is not
given) to staging, where the release branch can then rebase on staging.

Once a release is published, the release branch should perform a signed merge
commit into staging, followed by a signed merge commit from staging to main.
Any further pull requests to the branch after the series of releases is done
(which may be published after release, if strictly necessary) can target the
release branch, and the release branch will live on its own.
