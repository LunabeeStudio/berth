# Releasing

One script ships a release: `scripts/release/release.sh`. A person runs it, on a Mac. It needs no Claude and no CI.

The script tests and builds `berth` and `berth-bar` for macOS arm64, tags the commit, and publishes a GitHub release with `berth-macos-arm64.tar.gz` and its `.sha256`. It then bumps the plugin versions for the next release.

## Prerequisites

- A Mac with Apple silicon (macOS arm64).
- `git`, `gh`, `swift`, `plutil` and `python3` on PATH.
- `gh` authenticated: `gh auth login`.
- Your checkout on `main`, clean, and equal to `origin/main`.
- `PLANE_API_KEY` exported, only when you give no version.

The script checks all of this first and names the fix. It also stops if the tag `vX.Y.Z` or a release with that name already exists.

## Usage

```bash
scripts/release/release.sh [X.Y.Z] [--yes] [--dry-run]
```

- `X.Y.Z`: the version to ship. Without it, the script takes the lowest open Plane module titled `X.Y.Z`. With it, Plane is not read.
- `--dry-run`: run the checks, print the plan, change nothing, exit 0.
- `--yes`: skip the `Proceed? [y/N]` question.

Start with `--dry-run`. Then run it for real.

## What it does

The script prints one line per step.

1. Sets the plugin versions. If `plugin.json` and `marketplace.json` do not hold `X.Y.Z`, it opens a `release/set-X.Y.Z` PR, merges it at once, and pulls `main`. If they already do, it skips this.
2. Runs `swift test`.
3. Builds the two assets with `scripts/release/package.sh` into a temporary folder.
4. Tags `vX.Y.Z` and pushes the tag.
5. Creates a draft release with generated notes.
6. Uploads both assets to the draft.
7. Checks that both assets are on the draft, by name.
8. Publishes the release and marks it latest. Only now do `install.sh` and auto update see it.
9. Opens a `release/bump-X.(Y+1).0` PR that sets the plugin versions to `X.(Y+1).0`, and merges it at once.

Tests and build run before the tag is pushed. A failure there leaves no tag and no release.

The script never closes the Plane module. Do that yourself.

## If it fails

The script prints the step that failed and the output of that step. It never deletes anything itself.

Before the release is published, a tag or a draft release may be left behind. The script prints the cleanup commands for what this run created.

Delete the tag, locally and on GitHub:

```bash
git push --delete origin vX.Y.Z
git tag -d vX.Y.Z
```

Delete the draft release:

```bash
gh release delete vX.Y.Z
```

A version PR can be left half done. Switch to `main`, delete the local `release/…` branch, and close the PR or delete its remote branch.

Fix the cause, then run the script again. There is no resume: a rerun starts from the checks. If the version PR already merged, the script sees the versions and skips step 1.

After step 8 the release is live. Never delete it. If step 9 fails, open the bump PR to `X.(Y+1).0` by hand.
