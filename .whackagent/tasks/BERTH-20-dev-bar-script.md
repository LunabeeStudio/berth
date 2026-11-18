---
issue: BERTH-20
phase: validated
type: chore
wiki: []
note:
created: 2026-11-18
---

## Context / Decisions

Asked on 2026-11-18 while testing BERTH-19: "Add a script to launch it locally, ideally able to run side-by-side with prod bin". Decided with the user: a new ticket, not a round on BERTH-19, and a foreground script that Ctrl-C stops.

- `scripts/dev/run-bar.sh` builds the `berth-bar` product of the checkout it sits in (debug) and runs it in the foreground. It works from any worktree, because it finds the repository root from its own path, like `scripts/release/package.sh`.
- It runs next to the installed berth-bar. berth-bar never starts a daemon, so the dev bar connects to the daemon of the current `BERTH_HOME` (the default one unless set). It does not start a dev daemon: a second daemon would boot emulators of the same AVDs as the installed one.
- It exits with the bar's own status: 0 after a clean quit, the bar's exit code when it fails by itself.
- Ctrl-C quits it cleanly. A background job of a script ignores SIGINT, so the script traps INT and TERM and sends SIGTERM to the bar. berth-bar already handles SIGTERM as Quit, so `applicationWillTerminate` closes its scrcpy mirrors.
- Shared state, which the script prints at start and the README states: both items look the same in the menu bar, and Launch at login (`com.berth.bar` plist, the binary path inside it) and Auto update (`config.json`) are shared. Making them separate would need code in berth-bar, which this ticket does not include.

## Acceptance criteria

- `scripts/dev/run-bar.sh` builds `berth-bar` from the checkout it belongs to, in debug, and runs that binary in the foreground.
- The installed berth-bar keeps running while the dev bar runs and after it stops.
- Ctrl-C (SIGINT) or SIGTERM sent to the script makes the dev bar quit through its SIGTERM path, and the script then exits.
- The script prints which checkout and which `BERTH_HOME` it uses, and warns that Launch at login and Auto update are shared with the installed berth-bar.
- The README "Develop" section documents the script and the shared settings.

## Implementation

One brick, done in the session: `scripts/dev/run-bar.sh` (new, executable) and a paragraph in the README "Develop" section. No Swift change.

## Review

### validation — 2026-11-18

Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict clean after 2 rounds.

- Round 1, 1 finding, fixed: 🟡 the script always exited 0, because the loop ended on `wait "$pid" || true`, so a crashed bar looked like a clean run. It now keeps the status of the last `wait` and exits with it.
- Round 2: clean. Nothing withdrawn or disputed.

## Verification

- ✅ `BERTH_HOME=/tmp/bb20 scripts/dev/run-bar.sh` built the product from a cold worktree and started `.build/out/Products/Debug/berth-bar` as the script's child. The installed berth-bar (pid 920) kept running the whole time.
- ✅ SIGTERM to the script pid: the dev bar and the script both exited within 3 s.
- ✅ SIGINT to the script pid, with SIGINT restored to its default action (as in a terminal): the dev bar and the script both exited within 3 s.
- ✅ With a stub bar in place of the build: a bar that exits 3 makes the script exit 3, and SIGINT stops the bar through SIGTERM and the script exits 0.
- Note: a script started with `&` from a non-interactive shell inherits SIGINT as ignored, and bash cannot trap a signal ignored on entry. Only a terminal Ctrl-C proves the real case, and that needs a human.
- `desk-state`: no synthetic input was sent. The frontmost app changed from iTerm2 to Chrome during the second run while the cursor moved, which was the user's own activity. The dev bar never opened its popover, which is the only path that activates it.
