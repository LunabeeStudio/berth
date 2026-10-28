---
issue: BERTH-9
phase: in-progress
type: feature
wiki: [[release]]
note:
created: 2026-10-28
---

## Context / Decisions

Ticket: `scripts/release/release.sh` shipped v0.4.0 but left the Plane module 0.4.0 open. A human still had to close it in Plane or through `/wa-release`. User (2026-10-28): "Script should close if everything went well."

Decisions (2026-10-28):
- **New last step**, `10/10`, after the bump PR: `.github/board/wa-backlog close-milestone X.Y.Z` sets the module to `completed`. It runs only when every earlier step succeeded, since any failure stops the script before it.
- **Plane is read once, before any change**, when `PLANE_API_KEY` is set. That one read serves both the version lookup (no argument) and the close decision. The module stays open, and the plan says why, when:
  - `PLANE_API_KEY` is not set;
  - Plane can't be read: the release still ships when the version was given as an argument (the BERTH-7 rule: an argument means a release never depends on Plane);
  - no open module `X.Y.Z` exists.
  In each case step 10 prints that the module was left open and why, and the script exits 0.
- **Without an argument, Plane must be readable** (unchanged): no key or no answer → stop before any change, asking for `X.Y.Z`.
- **Step 10 fails** (Plane down by then, API error): the release is live and `main` is bumped. `on_error` says so and prints the manual close, `.github/board/wa-backlog close-milestone X.Y.Z` or the Plane UI. It never suggests deleting anything.
- The plan and step numbers go from `/9` to `/10`. `docs/RELEASING.md` and wiki [[release]] are updated to match.
- No check on the module's open tickets: the release is the signal (YAGNI).

## Acceptance criteria

- With `PLANE_API_KEY` set and module `X.Y.Z` open, a successful run closes it as step 10 and ends with `Released vX.Y.Z. main holds X.(Y+1).0. Plane module X.Y.Z closed.`
- With `PLANE_API_KEY` unset, unreadable Plane (version argument given) or no open module `X.Y.Z`, the plan line and step 10 say the module stays open and why. The release still runs, and the exit code is 0.
- Without a version argument, missing or unreadable Plane stops the script before any change (unchanged).
- A step 10 failure prints that the release is live and `main` is bumped, plus the manual close command, and no delete command.
- `--dry-run` shows the step 10 plan line and changes nothing, Plane included.
- `docs/RELEASING.md` and wiki [[release]] describe step 10.
- Proven end to end against a fake `gh`, `swift` and `wa-backlog` in a scratch clone: closing, the three skip reasons, and the step 10 failure.

## Implementation

## Review
