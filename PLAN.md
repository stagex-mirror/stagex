## Goal

Produce a branch updating staging packages to latest reproducible versions

## Steps

1. Make or continue from a branch 
 - should initially be identical to staging: updates-{user}-{date} 
   - e.g. updates-lrvick-2026-05-09
 - if we are already on a branch in that naming scheme stay on it
   - keeping any deviations from staging

2. Figure out package build order
  - Use GNU make to figure out the usual from-scratch build order 
    - Ensure you get a confirmed build order for all packages in the tree.
    - You may need to run make with dry-run flags and ignore the out dir
  - Be careful to not remove any docker build cache
    - building the whole tree takes hours.

3. Attempt to update and build every package in build order
  - Run "Check Package" proceedure for every package in the tree
  - Track with todo, and in PROGRESS.md

4. Report project complete 
  - Only if the tree is at latest versions possible
  - Only if the tree builds end to end reproducibly

## Suggestions
  - Track and maintain progress in PROGRESS.md or similar
  - Track what has been updated, what failed, what builds
  - Assume your session could crash and need to be restarted at any time
  - Assume the resuming session only knows about PLAN.md and PROGRESS.md
  - Do not commit PLAN.md or PROGRESS.md
    - But you can attach or summarize them in PR body
  - Be as succient as possible to conserve context
  - ignore bootstrap
  - work on only one package at a time from start to finish.
  - Explore origin/personal branches for changes that impact each apackage

## Proceedures

### Check Package
1. Find latest version
 - Use Anitya API, github releases, or web searches
 - Fall back to checking alpine or chimera versions
2. Update package if needed
 - Run "Update Package" proceedure if our version is out of date

### Update Package
1. Find and download an archive of the source code of the new version
2. Get a sha256 hash of the archive
3. Update the package.toml file for the package to point at the new version and hash
4. Attempt to build package with "Build Package" proceedure
  - Build in the background
  - Use PROGRESS=plain and log to a file
  - If successful proceed to "Reproduce Package"
  - Otherwise run "Repair Package"

### Repair Package
1. Research
  - Is this our first attempt at trying to fix this package?
    - Keep track of how many attempts you have made
    - If repeatedly failing, consider "Revert Package" and move on.
  - Are we repairing a reproducibility issue or a build failure? 
  - Inspect log file from the build for any clues
  - Is this related to changes in another dependency?
  - Will this require changes to another dependency?
  - Is this a common build error with a common solution?
  - Do chimera or alpine package this and how do we compare?
  - Are there specific considerations for reproducible builds needed?
  - Are there patches available we can adapt from other distros?
  - Are there open branches that update this package we can learn from?
  - Are there flag differences to consider in the new version?
2. Experiment
  - Attempt a specific set of experiments tasks to attempt fix the issue
  - Ensure we clean up after each exeriment and try one at a time
  - If an experiment is successful proceed with "Reproduce Package"
  - If all experiments fail proceed with "Revert Package"

### Reproduce Package
1. Note thesha256 digest for the index.json of the built package
2. Move the out directory folder for that package to a temporary directory
3. Rebuild the package a second time with NOCACHE=1
4. Ensure sha256 digest is identical
 - If hash is not identical run "Diff Package" on the old/new build dirs
 - Research output from "Diff Package" online or in source code
 - Run "Repair Package"

### Diff Package
1. Find the largest layer in each of old/new
2. Compare the largest layers using diffoscope
3. Save diffoscope log file for further study
   
### Revert Package
1. Research
 - Did the package fail to build?
  - If so do we have a build log?
 - Did it fail to reproduce?
  - If so, do we have a diffoscope log?
 - Were dependency conflicts a factor?
2. Document
 - Make a folder under "issues"
 - Incude build logs or diff files
 - Include the out directory or directories involved
 - Include detailed description of fixes attempted
3. File
 - Make a draft/wip issue on the stagex/stagex repo with the fj cli tool
 - include summary of what failed, and potential next steps.
 - attach build logs or diff files, truncating large ones as needed.
4. Restore
 - Use git to reset this specific package directory back to origin/staging
