---
issue: BERTH-7
phase: validated
type: feature
wiki: [[release]]
note:
created: 2026-10-28
---

## Context / Decisions

Ticket: shipping berth takes several manual steps (`docs/RELEASING.md`): set the plugin versions through a PR, tag, wait for the Release workflow, check the assets. Add a maintainer script that a human runs alone, without Claude, and that handles the whole flow.

Decisions from the user (2026-10-28):
- **A repo script, not a CLI subcommand**: `scripts/release/release.sh`. `berth release` stays the device give-back verb: agents, the skill and the guard rules depend on it.
- **It runs without Claude**: plain bash, using only `git`, `gh`, `swift`, `plutil`, `python3` and the repo's own scripts.
- **No TeamCity.** The build runs on this Mac: the script calls `scripts/release/package.sh` and uploads the assets itself.
- **The tag-triggered publish in `.github/workflows/release.yml` goes away**, so the local build is the only publisher and the two never race on the same tag.

Decisions (unattended grill, 2026-10-28):
- **Usage**: `scripts/release/release.sh [X.Y.Z] [--yes] [--dry-run]`. (autopilot assumption)
- **Version source**: the argument when given. Without it, the lowest open Plane module whose title is `X.Y.Z`, read through `.github/board/wa-backlog milestones` (needs `PLANE_API_KEY`). No open module, or `PLANE_API_KEY` missing → stop and ask for the argument. With the argument, Plane is not read, so a release never depends on Plane being up. (autopilot assumption)
- **Prerequisites, checked before anything else; each failure names the fix**: `gh` installed and authenticated (`gh auth status`); `swift`, `plutil`, `python3` on PATH; macOS arm64 (`package.sh` builds arm64); the checkout is on `main`, clean, and equal to `origin/main` after a fetch; tag `vX.Y.Z` exists neither locally nor on `origin`; no GitHub release exists for `vX.Y.Z`. (autopilot assumption)
- **Plan and confirmation**: after the checks, the script prints every step it will take (version PR or "versions already X.Y.Z", tag, draft release, assets, publish, next version PR) and asks `Proceed? [y/N]`. `--yes` skips the question. `--dry-run` prints the plan and exits 0 without changing anything, local or remote. (autopilot assumption)
- **Order, safest first** (autopilot assumption: the build runs before the tag is pushed, so a failed test or build leaves no public tag behind):
  1. **Set or verify the version.** Both `claude-plugin/.claude-plugin/plugin.json` (`version`) and `.claude-plugin/marketplace.json` (`plugins[0].version`) already `X.Y.Z` → nothing to do. Otherwise: branch `release/set-X.Y.Z` from `main`, set both values (edit the version line in place, file formatting unchanged, then re-read with `plutil` to check), commit, push, open a PR, merge it at once with `gh pr merge --squash` (merge direct, no review: `main` is not protected), switch back to `main`, `git pull --ff-only`, delete the local branch.
  2. **Test and build** on the release commit: `swift test`, then `scripts/release/package.sh X.Y.Z <temp dir>`.
  3. **Tag** `vX.Y.Z` on that commit and push the tag.
  4. **Draft release**: `gh release create vX.Y.Z --draft --verify-tag --generate-notes --title vX.Y.Z`.
  5. **Upload** `berth-macos-arm64.tar.gz` and `berth-macos-arm64.tar.gz.sha256` to the draft.
  6. **Verify** both assets are attached to the draft (`gh release view --json assets`), by exact name. Missing → stop, the draft stays a draft.
  7. **Publish**: `gh release edit vX.Y.Z --draft=false --latest`. Only now does `releases/latest` move, which is what `install.sh` and auto update read ([[update]]).
  8. **Bump the minor version for the next release**: `X.(Y+1).0` in both plugin files, through branch `release/bump-X.(Y+1).0`, PR, merge direct, pull, as in step 1.
- **Failure handling**: `set -euo pipefail`. Each step prints what it is doing. A failure prints the step that failed and the cleanup for what is already public (delete the tag, delete the draft release), as `docs/RELEASING.md` describes. The script never deletes a tag or a release itself. No resume mode. (autopilot assumption)
- **The Plane module is not closed** by the script and no next module is created: humans manage Plane modules. (autopilot assumption)
- **`.github/workflows/release.yml`** keeps only the pull-request build check (version `0.0.0`: test, package, upload artifact) for PRs touching the workflow, `scripts/release/**`, `Package.swift` or `Version.swift`. The `push: tags` trigger, the tag version check and the `publish` job are removed. The tag/plugin version check moves into the script.
- **Asset names stay** `berth-macos-arm64.tar.gz` and `.sha256`: `install.sh`, the README and auto update rely on them.
- **Docs**: `docs/RELEASING.md` rewritten around the script (prerequisites, usage, what each step does, cleanup after a failure). Wiki [[release]] updated.

## Acceptance criteria

- `scripts/release/release.sh` exists, is executable, and needs no Claude: bash plus `git`, `gh`, `swift`, `plutil`, `python3`.
- Prerequisites fail fast with a message naming the fix, before any change: `gh` missing or not authenticated, not on `main`, dirty tree, `main` behind or ahead of `origin/main`, tag `vX.Y.Z` already present locally or on `origin`, release `vX.Y.Z` already present, bad version format, not macOS arm64.
- Without a version argument, the version is the lowest open Plane module titled `X.Y.Z`; no module or no `PLANE_API_KEY` → exit non-zero asking for the argument.
- Plugin versions different from `X.Y.Z` → both files set to `X.Y.Z` through a PR merged at once, and `main` pulled; already equal → no PR.
- `swift test` and `package.sh` run before the tag is pushed; a failure there leaves no tag and no release.
- Tag `vX.Y.Z` pushed, draft release created with generated notes, both assets uploaded; the release is published only after both assets are verified on the draft.
- After publishing, both plugin files hold `X.(Y+1).0` on `main`, through a PR merged at once.
- `--dry-run` prints the full plan and changes nothing, local or remote; without `--yes` the script asks before the first change.
- `.github/workflows/release.yml` no longer runs on tags and has no publish job; its PR build check still works.
- `docs/RELEASING.md` describes the script flow and the cleanup after a failure.
- A real release (`scripts/release/release.sh 0.4.0`) ships `v0.4.0` with both assets and leaves `0.5.0` on `main`. (Human check: an agent never publishes a release.)

## Implementation

One brick (autopilot, 2026-10-28), then three autofix rounds.
- `scripts/release/release.sh` (new, executable):
  - Parses `[X.Y.Z] [--yes] [--dry-run]`. One shared pattern (`semver_part`, `semver`) rejects leading zeros, for the argument and for Plane module titles.
  - Without an argument, `lowest_plane_version` reads `.github/board/wa-backlog milestones`.
  - Checks run before any change, in this order:
    - `check_tools`: tools on PATH, `gh auth status`, macOS arm64.
    - `check_main`: on `main`; clean tree with `--untracked-files=normal`; equal to `origin/main` after a fetch.
    - `check_version_free`: the local tag; the remote tag with `ls-remote --exit-code` (exit 2 = absent, any other failure stops); the release with `gh api …/releases/tags/<tag>` (only HTTP 404 = absent); a leftover draft with `gh release list`.
  - Then the script prints the plan and asks `Proceed? [y/N]`. `--yes` skips the question; `--dry-run` exits 0 after the plan.
  - Steps 1 to 9 follow the Decisions order. `version_pr` handles both the set and the bump:
    - branch `release/<kind>-<version>`, then a `sed` on the `"version"` lines;
    - re-check the versions with `plutil`, commit, push;
    - `gh pr create`, then `gh pr merge --squash --delete-branch`;
    - pull, delete the local branch.
  - `swift test` and `package.sh` output stays on screen.
  - ERR trap (`set -E`): it returns silently in subshells. In the main shell it prints the failed step, then the cleanup for what the run created:
    - a half-done version PR;
    - the tag and draft delete commands;
    - after publish, "release is live, do not delete it" instead.
- `.github/workflows/release.yml`: drops the tag trigger, the tag/version check and the `publish` job. It keeps the PR build check (`swift test` + `package.sh 0.0.0` + artifact).
- `docs/RELEASING.md`: rewritten around the script, covering prerequisites, usage, the steps and the cleanup after a failure.
- Wiki [[release]]: rewritten for the script flow.

Runtime check (CLI, in a scratch clone with a bare origin and `GH_REPO=LunabeeStudio/berth`; nothing written to GitHub):
- `bash -n` OK. `shellcheck` is not installed.
- `--dry-run 9.9.9`: plan printed, exit 0, refs and status unchanged.
- No argument with `PLANE_API_KEY` set, `--dry-run`: "Version 0.4.0 (lowest open Plane module)", exit 0.
- Failures, each with a message naming the fix:
  - `1.2` and `01.2.3` exit 64.
  - Exit 1 for: wrong branch; dirty tree; untracked file; main ahead of origin; local tag; remote tag; real `v0.3.0` release (read-only `gh api`); no argument without `PLANE_API_KEY`.
- Prompt answered `n`: exit 1, nothing changed.
- Forced failures, with a fake `gh` and `swift` in the scratch directory: each prints one FAILED block.
  - Step 2 fails: no cleanup lines.
  - Step 6 fails: the tag and draft delete commands.
  - Step 9 fails after publish: the PR cleanup lines and "Release v9.9.9 is live, do not delete it", with no delete-release command.
- `swift build` green.
- Not run: the real flow against GitHub (version PR, tag, release, upload, publish, bump). It is left to the human release check.

## Review

### validation (autopilot) — 2026-10-28
LENSES: style ✓ · elegance ✓ · structure ✓ · correctness ✓
- Round 1: 1 major and 9 minor findings.
  - Major [correctness]: a failure at step 9, after publish, printed delete commands for the live release.
  - Minor:
    - remote tag and release checks read any failure as "absent";
    - version PR branches were left on origin, with no cleanup output;
    - the cleanup block printed twice from command substitutions;
    - test and build output was discarded;
    - untracked files could hide behind `status.showUntrackedFiles=no`;
    - leading zeros crashed `next_minor`;
    - the wiki was not synced (orchestrator synced it);
    - 2 function renames.
  - All fixed by autofix.
- Round 2: 2 minor findings, both fixed: Plane titles skipped the leading-zero rule, and `version_pr` had an unused `kind`.
- Round 3: 1 minor [structure] finding: the pattern was built twice. Fixed exactly as suggested: the anchored `$semver` is passed to Python. The orchestrator checked it: `0.4.0` and `10.20.3` match; `0.08.0` and `1.2` don't. The no-argument and `9.9.9` dry runs exit 0.
- Clean. The wiki [[release]] is synced and checked against the script by the verifier.
