---
issue: BERTH-15
phase: validated
type: feature
wiki: [[update]], [[release]]
note: Tap repo LunabeeStudio/homebrew-tap created by a human, private, empty. First formula lands at the 0.6.0 release.
created: 2026-11-12
---

## Context / Decisions

Ticket idea, pasted 2026-11-12: "Improve the setup: make it installable with brew (check if it collides with auto-update)."

Today berth installs with `install.sh` or a manual `curl | tar` into `~/.local/bin`, and keeps itself current with `berth update` and the daemon's auto update. Every path that matters goes through `LaunchAgent.currentExecutablePath()`, which resolves symlinks. Under Homebrew that gives the versioned keg path `<prefix>/Cellar/berth/<version>/bin/berth`. Three problems follow:
- The updater renames the new binary into the keg, so Homebrew still records the old version and the next `brew upgrade` fights it.
- `berth daemon install` and the berth-bar "Launch at login" plist record the keg path. `brew upgrade` cleans the old keg, so both launchd agents point at a deleted file.
- The daemon watches and re-execs the keg path, so it never picks up the new version after `brew upgrade`.

Decisions:
- **Channel.** A Homebrew formula (not a cask: berth is a bare CLI plus a menu-bar binary, no `.app`) in the tap repository `LunabeeStudio/homebrew-tap`, at `Formula/berth.rb`. The formula installs the prebuilt release asset `berth-macos-arm64.tar.gz` from the public berth release (`url` + `sha256`), and puts `berth` and `berth-bar` in `bin`. It does not build from source, because that needs Xcode 27 on the user's Mac. It declares macOS and arm64 only, and its `test` block runs `berth --version`.
- **Private tap.** The tap repository stays private, so Homebrew is an install channel for Lunabee members with GitHub access only. Install: `brew tap lunabeestudio/tap` then `brew install berth` (or `brew install lunabeestudio/tap/berth`). `install.sh` stays the public channel.
- **No `brew services`.** The formula has no `service` block: a Homebrew service would be a second launchd agent beside `com.berth.daemon`, and two agents could start two daemons. The formula's `caveats` print the next steps: `berth prepare <AVD>`, `berth status`, optional `berth daemon install`, and `berth-bar` for the menu bar.
- **Homebrew detection.** New BerthCore feature folder `Sources/BerthCore/Homebrew/`, with `HomebrewInstall.swift`: a pure function from the resolved executable path to the install kind. A path `<prefix>/Cellar/berth/<version>/bin/<name>` is a Homebrew install. Its stable path is `<prefix>/opt/berth/bin/<name>`, with the prefix taken from the path itself, so `/opt/homebrew`, `/usr/local` and custom prefixes all work. The stable path is used only when that file exists; otherwise berth behaves as a direct install. Tests mirror it in `Tests/BerthCoreTests/Homebrew/`.
- **Stable path everywhere.** `LaunchAgent.currentExecutablePath()` returns the stable opt path on a Homebrew install. So the `berth daemon install` plist, the berth-bar "Launch at login" plist, the daemon's `ExecutableWatch` and its `execv` all use `<prefix>/opt/berth/bin/…`. `stat` follows the opt symlink, so `brew upgrade` looks like a binary change: the idle daemon re-execs into the new version with the same pid, through the existing `ReexecMonitor` path (`codesign --verify`, `Broker.performIfIdle`). Direct installs are unchanged.
- **Homebrew owns updates.** On a Homebrew install:
  - `berth update` and `berth update --check` refuse with exit 1 and `berth: installed by Homebrew, run brew upgrade berth` (new `UpdateError.homebrew`, thrown by `Updater` before any network call).
  - The daemon's `AutoUpdater` never checks, whatever `autoUpdate` says, like a `dev` build. It logs one line at start saying auto update is off because Homebrew manages berth.
  - The berth-bar "Auto update" checkbox is disabled and unchecked, with the tooltip `Updated by Homebrew: brew upgrade berth`. `AutoUpdateSetting` gets an `isManagedByHomebrew` flag. The bar writes nothing to `config.json` in that state. No extra caption line.
- **Release flow.** `scripts/release/release.sh` gets a new step right after the release goes live (after step 8, before the version bump):
  - It renders the formula from a template kept in this repository, `scripts/release/homebrew/berth.rb`, with placeholders for the version and the SHA-256. The SHA comes from the `.sha256` asset the script just built.
  - It commits the rendered file to `LunabeeStudio/homebrew-tap`, `Formula/berth.rb` on the default branch, with `gh api -X PUT repos/LunabeeStudio/homebrew-tap/contents/Formula/berth.rb` (no clone; this also works on the empty repository for the first release).
  - The plan printout lists the step, and `--dry-run` prints the rendered formula. A dry run exits before the build, so the SHA-256 shows as the placeholder `<sha256 of the built archive>`. (autopilot assumption)
  - Preflight, before any change: the tap repository is reachable and the `gh` user can push to it. Otherwise the script stops and nothing is public.
  - A failure in this step happens after publish: the script prints the manual fix, like the other post-publish steps, and never deletes the tag or the release.
- **First formula.** The first formula is published by release.sh at 0.6.0, the first release that contains the Homebrew detection. No formula for 0.5.0: a Homebrew install of 0.5.0 would self-update inside the keg, which is the clash this ticket removes.
- **Mixed installs.** No code. The README tells users to pick one channel and to remove `~/.local/bin/berth` and `~/.local/bin/berth-bar` before switching to Homebrew. `install.sh` is unchanged.
- **Docs.** README Install: a "Homebrew (Lunabee members)" block with the tap and install commands, the GitHub access it needs, the pick-one-channel line, and that `brew upgrade berth` updates (the daemon picks it up when idle). README Updates: `berth update` and auto update are off under Homebrew. `docs/RELEASING.md`: the formula step and the tap preflight. Wiki `update` (Homebrew owns updates, stable opt path) and `release` (formula step, tap repository).
- **Out of scope (YAGNI).** homebrew-core submission, a cask, an Intel build, a `brew services` block, bottles built from source, detection of mixed installs in `install.sh`.

Prior art:
- Homebrew cask: made for `.app` bundles and binaries shipped inside them. berth ships two bare binaries. Not used.
- homebrew-core: refuses binary-only formulas of young projects and needs a source build. Not used.
- A tap formula downloading a prebuilt release tarball is the usual pattern for Go and Rust CLIs (for example the GoReleaser-generated taps). Chosen, written by hand: GoReleaser does not build Swift, and the formula is a few lines.

## Acceptance criteria

- `swift build` and `swift test` pass.
- A unit test shows that a resolved executable path `<prefix>/Cellar/berth/<version>/bin/berth` is detected as a Homebrew install with stable path `<prefix>/opt/berth/bin/berth`, for `/opt/homebrew`, `/usr/local` and a custom prefix, and that `~/.local/bin/berth`, a `.build` path, and a keg path whose opt file is missing are direct installs.
- On a Homebrew install, `berth update` and `berth update --check` exit 1 with `berth: installed by Homebrew, run brew upgrade berth`, make no network request, and change no file.
- On a Homebrew install, the daemon never checks for updates, even with `autoUpdate` true or absent, and `daemon.log` has one line at start saying Homebrew manages updates.
- On a Homebrew install, `berth daemon install` writes `com.berth.daemon.plist` with `ProgramArguments[0]` = `<prefix>/opt/berth/bin/berth`, and enabling "Launch at login" writes `com.berth.bar.plist` with `<prefix>/opt/berth/bin/berth-bar`.
- On a Homebrew install, after `brew upgrade berth`, the idle daemon re-execs with the same pid, and `daemon.log` shows it starting with the new version. While a lease is held it does not re-exec.
- On a Homebrew install, the berth-bar "Auto update" checkbox is disabled and unchecked, shows the tooltip `Updated by Homebrew: brew upgrade berth`, and the bar writes nothing to `config.json`. The render tests show this state in light and dark.
- On a direct install (`~/.local/bin`, `install.sh`, `.build`), `berth update`, auto update, the plists, the re-exec and the checkbox behave exactly as before.
- The rendered formula passes `brew audit --strict` and `brew style`. Installed from a local throwaway tap with a locally packaged tarball, `brew install` puts `berth` and `berth-bar` on PATH, `brew test berth` passes, the caveats print the next steps, `brew upgrade` to a second local version works, and the tap is removed afterwards.
- `release.sh --dry-run` lists the formula step and prints the rendered formula with the version. The SHA-256 shows as a placeholder, because a dry run exits before the build. (autopilot assumption)
- `release.sh` stops in preflight, before any change, when the tap repository is unreachable or the `gh` user cannot push to it.
- README documents the Homebrew install for Lunabee members, the pick-one-channel rule, and that `berth update` and auto update are off under Homebrew. `docs/RELEASING.md` documents the formula step.

## Implementation

Autopilot run, 2026-11-12. One implementer, 3 bricks.

- Brick 1, BerthCore:
  - `Homebrew/HomebrewInstall` (new): `init?(resolvedPath:fileExists:)` matches `<prefix>/Cellar/berth/<version>/bin/<name>` and needs `<prefix>/opt/berth/bin/<name>` to exist. It exposes `stablePath`. `current()` reads the running executable.
  - `LaunchAgent.currentExecutablePath()` returns the stable path on a Homebrew install, and the resolved path otherwise.
  - `UpdateError.homebrew`. `Updater` takes `isHomebrew` (default from `HomebrewInstall.current()`). `check()` and `install()` throw it first, before the dev-build check and before any network call.
  - Tests: `HomebrewInstallTests`, plus an `UpdaterTests` case (no request, file unchanged).
- Brick 2, daemon and bar:
  - `AutoUpdater` takes `isHomebrew`. On a Homebrew install `run()` logs `auto update off: berth is managed by Homebrew (brew upgrade berth)` once and returns.
  - `AutoUpdateSetting.isManagedByHomebrew`: reads unchecked, unavailable, and writes nothing.
  - `StatusPanel`: `.help("Updated by Homebrew: brew upgrade berth")` only in that state.
  - Tests: `AutoUpdaterTests`, `AutoUpdateSettingTests`, and render tests `auto-update-homebrew` in light and dark.
- Brick 3, release and docs:
  - `scripts/release/homebrew/berth.rb` (template, `{{VERSION}}` and `{{SHA256}}`) and `render.sh <X.Y.Z> <sha256>`, the one place that renders.
  - `release.sh`: preflight `check_tap` (reachable, `permissions.push`). New step 9/11 `publish_formula` (GET the existing `sha`, 404 = first release, then `gh api -X PUT …/contents/Formula/berth.rb`). Steps renumbered to n/11. The failure text for the post-publish steps prints the manual formula fix. The dry run prints the formula with the SHA placeholder.
  - README Install and Updates, `docs/RELEASING.md`.
- The formula has no `version` line (it is redundant with the URL, and audit flags it). `depends_on arch: :arm64` comes before `:macos`, the order `brew style` requires.
- Build ✅ · tests ✅ (all suites) · no new warnings.

## Review

Round `validation (autopilot)`. LENSES: style ✓ · elegance ✓ · structure ✓ · correctness ✓.

- Pass 1: 5 minor findings, all fixed, none withdrawn or disputed:
  - `HomebrewInstall`: `guard case let` binding with index math → typed `keg` array.
  - `HomebrewInstall`: `stablePath` and the init made internal; only `current()` stays public.
  - `AutoUpdateSetting`: redundant `!isManagedByHomebrew` in the setter removed.
  - `UpdateFixture`: unused `isHomebrew` parameter removed.
  - Wiki `update` and `release` not updated → synced (Homebrew detection, formula step, step numbering).
- Pass 2: clean. Build ✅, `swift test` 72 tests in 8 suites ✅, Homebrew refusal re-checked at runtime.

## Verification

Run by the agent:
- ✅ Simulated Homebrew layout (keg, `opt` symlink, `bin` symlink, stamped 0.0.1): `berth update --check` and `berth update` print `berth: installed by Homebrew, run brew upgrade berth`, exit 1, keg unchanged, no network call (`BERTH_UPDATE_URL` unreachable). A plain copy still gets the network error, and a `dev` build still gets `dev build cannot be updated`.
- ✅ Daemon started from the simulated Homebrew install (`BERTH_HOME` scratch, empty pool): `daemon.log` shows `starting v0.0.1`, then the auto-update-off line. Simulated upgrade (0.0.2 keg, `opt` symlink retargeted, 0.0.1 keg removed): about 11 s later `re-exec after binary change`, `daemon <same pid> starting v0.0.2`, and `berth status` answers. A direct-install daemon logs no Homebrew line.
- ✅ Render PNGs checked: the "Auto update" checkbox is greyed out and unchecked in light and dark under Homebrew. The tooltip is not visible in a PNG.
- ✅ `bash -n` on `release.sh` and `render.sh`. Dry run (temporary copy without the `main` check, deleted): the plan lists step 9 and prints the rendered formula. The real tap preflight passes. A copy pointed at a missing repository stops in preflight with HTTP 404.
- ✅ Local throwaway tap `local/berth15`, archives from `package.sh 0.0.1` and `0.0.2` over file:// URLs: `brew install` puts `berth` and `berth-bar` in `/opt/homebrew/opt/berth/bin`, `berth --version` prints 0.0.1, the caveats print, `brew test` passes, `berth update` from Homebrew's bin refuses with the Homebrew message. `brew upgrade` gives 0.0.2, with only the 0.0.2 keg left and `opt/berth` pointing at it. Then uninstall and untap: no `berth` keg, no `opt/berth`, no local tap.
- ✅ `brew style`: no offenses. `brew audit --strict`: no findings on the GitHub-URL rendering. `--online` only reports the v0.6.0 URL 404, expected before the release.
- Not run by agent: the plists written by a real `berth daemon install` and a real "Launch at login" toggle (they would overwrite the user's own agents; both take `currentExecutablePath()`, covered by `HomebrewInstallTests`), the tooltip on hover, a real release pushing the formula to the tap, the "cannot push" preflight branch, a real `brew upgrade` with a leased emulator.

## Feedback
