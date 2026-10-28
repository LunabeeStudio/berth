---
issue: BERTH-8
phase: in-progress
type: bug
wiki: [[release]]
note:
created: 2026-10-28
---

## Context / Decisions

Ticket: the first real run, `scripts/release/release.sh 0.4.0 --yes`, stopped at step 1 with `line 144: kind: unbound variable`. `version_pr` declares `local kind="$1" target="$2" message="$3" branch="release/$kind-$target"` on one line. Bash expands every word of a `local` command before it assigns any, so `$kind` and `$target` are still unset when `branch` is built, and `set -u` aborts. The run changed nothing: no branch, no PR, no tag. BERTH-7's autofix round 2 brought the bug in, when it replaced `release/$1-$2`. The fake-`gh` failure tests had run before that round, and `--dry-run` never reaches `version_pr`.

Decisions (2026-10-28):
- Build `branch` on its own `local` line, after `kind` and `target` are set.
- Prove the whole flow end to end, with no GitHub write. Use a scratch clone whose `origin` is a local bare repo, a fake `gh` and a fake `swift` first on `PATH`, and the real `package.sh`. The fake `gh pr merge` fast-forwards `main` in the bare origin. The run must reach `Released v9.9.0. main holds 9.10.0.` and print both version PRs, the tag, the draft, the upload, the check and the publish.

## Acceptance criteria

- `version_pr` builds `release/<kind>-<version>` with `set -u` on, for both the set and the bump call.
- A full run against a fake `gh` and `swift` in a scratch clone exits 0. The set PR is merged into `main`, tag `v9.9.0` is on the set commit, the draft is created and both assets are uploaded and checked, the release is published, and `main` ends at `9.10.0` in both plugin files.
- `bash -n` passes, and `--dry-run` still changes nothing.

## Implementation

## Review
