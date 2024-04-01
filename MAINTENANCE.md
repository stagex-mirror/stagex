## Pull Requests

Pull requests for every change should follow the given flow:
`pull-request-branch -> staging -> current-release-branch -> main`. Making a
commit short-cut the staging or the release branch removes the ability to track
who approves contributions and when those contributions has been approved. Even
if a patch is necessary for a release, it _must_ flow from a PR, to staging, to
the release branch.

Pull requests should be merged using a signed merge commit. To configure your
Git porcelain to always use merge commits, run `git config merge.ff false`. To
configure your Git porcelain to always sign commits, run `git config
commit.gpgsign true`.

## Release Branches

Release branches take the format `YYYY.MM.release`. A release should include a
PR to staging to introduce a bump to `digests.txt`, then cut into its own
branch. Once the branch is created, other users can begin reproducing. The
release engineer should run `make sign` to ensure a signature exists for every
package.

Any commits required once the branch is created, but before the release is
published, should flow from the PR branch, to staging, to the release branch.

Once a release is published, the branch should perform a signed merge commit
into main. Any further pull requests to the branch (which may be published
after release, if strictly necessary) can target the release branch directory,
and the release branch will live on its own.
