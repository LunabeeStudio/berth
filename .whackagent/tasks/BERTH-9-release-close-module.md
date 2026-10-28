---
issue: BERTH-9
phase: validated
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

Orchestrator, 2026-10-28.
- `scripts/release/release.sh`:
  - Plane is read once, before any change, when `PLANE_API_KEY` is set. `module_kept` holds the reason the module stays open: no key, Plane unreadable, or no open module `X.Y.Z`. Empty means step 10 closes it.
  - `lowest_plane_version` now takes the milestones JSON. `plane_module_open` is new.
  - Without an argument, the guard tests `module_kept`, not the read's output, so a failed read that printed something still stops the script.
  - Plan line 10 and step `10/10`: close through `wa-backlog close-milestone`, or "left open: <reason>". The final line names the result.
  - New `bumped` flag. A step 10 failure prints that the release is live and `main` is bumped, plus the manual close. A step 9 failure also hints at the close when the module was going to be closed.
  - Steps renumbered `/10`.
- `docs/RELEASING.md` and wiki [[release]]: step 10, the skip reasons, and the manual close after a failure.

Proof: scratch clone with a local bare `origin`, a fake `gh`, `swift` and `wa-backlog`, and the real `package.sh`. Nothing was written to GitHub or Plane.

| Case | Exit | Result |
|---|---|---|
| Open module | 0 | closed, "Plane module 9.9.0 closed." |
| No key, with argument | 0 | left open, reason given, no close call |
| Plane down, with argument | 0 | left open, reason given, no close call |
| No open module, with argument | 0 | left open, reason given, no close call |
| No argument, open module | 0 | resolves 9.9.0, closes it |
| No argument, Plane down | 1 | stops before any change |
| No argument, Plane fails after partial output | 1 | stops before any change |
| No argument, no key | 1 | stops before any change |
| Close fails | 1 | live and bumped message, plus the manual close command |
| Bump fails | 1 | live message, plus the close hint (with key) or no hint (no key) |
| `--dry-run` | 0 | plan line 10, no close call |

## Review

### validation — 2026-10-28
LENSES: style ✓ · elegance ✓ · structure ✓ · correctness ✓
- 2 minor [correctness] findings:
  - The no-argument guard tested `$milestones`, so a failed read that printed partial output got through.
  - A step 9 failure didn't mention closing the module, which the docs promise.
- Both fixed exactly as recommended, and the scenarios re-run green: partial read → exit 1; bump failure → close hint.
- The verifier found no other `set -u`, ERR or expansion issue in the whole script. The wiki [[release]] is synced.
