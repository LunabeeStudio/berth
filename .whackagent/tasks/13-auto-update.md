---
issue: 13
phase: in-progress
wiki: [[architecture]], [[cli]], [[release]]
note: Depends on #11 (version in `BerthCore/Version.swift`, release asset names).
created: 2026-10-16
---

## Context / Decisions

Source: issue #13 body, user request "auto update" (`/wa-autopilot --afk`, 2026-10-16). Grilled unattended: every decision below tagged `(autopilot assumption)` was picked by the agent and waits for the user's confirmation.

Goal: an installed berth keeps itself on the latest GitHub release, with no action from the user.

Builds on #11: the version string lives in `BerthCore/Version.swift` (`dev` in local builds), and each release carries `berth-macos-arm64.tar.gz` (`berth` + `berth-bar`) and `berth-macos-arm64.tar.gz.sha256`.

- Two entry points share one updater in BerthCore: a manual `berth update` command (`--check` only reports), and an automatic check in the daemon. (autopilot assumption)
- Feed: the GitHub "latest release" API, `https://api.github.com/repos/LunabeeStudio/berth/releases/latest` (`tag_name`, `assets[].browser_download_url`). Prereleases are excluded by that endpoint. The env variable `BERTH_UPDATE_URL` replaces that URL, for tests and runtime proofs against a local server. (autopilot assumption)
- A release is newer when its `X.Y.Z` (tag minus `v`) is numerically greater than the running version. Only a strictly newer release installs. A `dev` build never updates: `berth update` refuses with a message and exit 1, and the daemon never checks. (autopilot assumption)
- Install: download the archive and its `.sha256`, verify SHA-256 (CryptoKit), extract with `/usr/bin/tar` into a temp directory inside the target directory, then replace `berth` at the resolved path of the running executable, and `berth-bar` when a file of that name sits beside it. Each replacement is an atomic rename, mode 0755. Running processes keep the old file, so replacing it under them is safe. Checksum mismatch or any failure → nothing replaced. (autopilot assumption)
- Target directory not writable (root-owned install) → error naming the directory, exit 1 for `berth update`, a log line for the daemon. (autopilot assumption)
- Daemon automatic update: config key `autoUpdate`, default `true`; an existing config without the key reads as `true`. First check about one minute after daemon start, then every 24 h. Newer release → install as above. Network or checksum failure → logged in `daemon.log`, retried at the next period, daemon keeps serving. (autopilot assumption)
- Daemon reload: the daemon notices that its own executable file changed on disk (identity recorded at start: inode, size, modification date). Then, as soon as it is idle (no lease, no waiting claim, no slot booting, resetting or stopping), it re-execs itself in place (`execv`, same pid, same arguments). Same pid keeps the launchd agent `com.berth.daemon` tracking it, and emulators are adopted by the existing state restore. This also covers `berth update` run by hand and a binary copied by hand. Lock and socket file descriptors must not survive the exec, else the new image cannot take the lock. (autopilot assumption)
- `berth-bar`: its file is replaced, a running instance keeps the old version until it is relaunched. No automatic relaunch. (autopilot assumption)
- Daemon start log line includes the version, so a re-exec is visible in `daemon.log`.
- Out of scope (YAGNI): berth-bar relaunch, rollback command, update channels or prereleases, signature beyond the SHA-256 file, an "update available" notice in other commands.

Prior art:
- Sparkle: self-update for `.app` bundles, needs an appcast and EdDSA keys; not built for a bare CLI binary. Not used.
- No maintained SwiftPM library for self-updating a command-line binary was found; the job is a JSON fetch, a download, a checksum and a rename. Custom build decided.
- Homebrew: an install channel, not a self-update mechanism; out of scope (see #11).

## Acceptance criteria

- `berth update --check` prints the running version and the latest release version, changes no file, and exits 0.
- `berth update`, when a newer release exists, replaces `berth` and the `berth-bar` beside it, then prints `berth: updated <old> → <new>`; `berth --version` then prints the new version.
- `berth update`, when already on the latest release, prints `berth: up to date (<version>)` and changes no file.
- A checksum mismatch makes `berth update` fail with exit 1 and leaves both binaries untouched.
- A `dev` build refuses `berth update` with a message and exit 1, and its daemon never checks for updates.
- An install directory that is not writable makes `berth update` fail with exit 1 and a message naming the directory.
- A daemon with `autoUpdate` true (or the key absent) installs a newer release on its own about one minute after start, and logs it in `daemon.log`.
- A daemon with `autoUpdate: false` never checks for updates.
- After its executable changes on disk, the daemon re-execs with the same pid once it is idle, and `daemon.log` shows it starting with the new version.
- While a lease is held, the daemon does not re-exec; it re-execs after the lease is released, and leases and emulators survive.
- A network failure during an automatic check is logged and the daemon keeps answering commands.
- README documents `berth update` and the `autoUpdate` config key.

## Implementation

## Review

## Verification

## Feedback
