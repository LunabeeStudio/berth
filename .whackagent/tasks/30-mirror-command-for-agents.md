---
issue: 30
phase: review
type: feature
wiki: [[cli]], [[claude-code]], [[architecture]]
note: Depends on #29 (iOS DeviceHub mirror): its DeviceHub URL builder and opener move to BerthCore here. Code after #29 merges.
created: 2026-10-20
---

## Context / Decisions

User request (2026-10-20): "Sometimes claude needs human action on berth managed device, like for login. Add a command to allow claude to show device window (scrcpy/ios mirror feature wip) and make sure claude discover it."

berth boots its emulators with `-no-window` and its simulators headless, so a human cannot see or touch the device an agent holds. #22 added a Mirror button in the `berth-bar` panel (scrcpy for Android), and #29 adds the iOS one (DeviceHub, `devices://device/open?id=<udid>`). Both work only from a click in the panel. This ticket gives agents a command for the same window, so that an agent can hand the device to a human (login, 2FA, captcha) and then continue.

Decisions (grill, 2026-10-20):
- **Command.** `berth mirror <serial>` takes the serial of an emulator or the UDID of a simulator. The argument is required: there is no default from `ANDROID_SERIAL` or `SIMULATOR_UDID`, and no lease id (YAGNI).
- **The CLI opens the window itself.** It asks the daemon for a `status` snapshot (`autoSpawn: false`, like `release`) and finds the slot and its platform from the pool. Android → the CLI starts scrcpy detached (`Spawn.detached`), with `ADB=<Config.resolvedSDKRoot>/platform-tools/adb` so scrcpy talks to berth's adb server. iOS → the CLI opens `devices://device/open?id=<udid>` with the NSWorkspace opener from #29. There is no protocol, daemon or broker change, and `berth-bar` does not need to run.
- **Both platforms, blocked by #29.** #29 brings the DeviceHub URL builder and opener. This ticket moves them to BerthCore and does not write a second copy, so it is coded after #29 merges.
- **Which devices.** The slot must be in state `leased`. There is no owner check, as with `release` and `renew`: owner detection is heuristic and could refuse the real holder. Errors exit 1 with one stderr line:
  - unknown serial → `berth: <serial> is not a berth device`;
  - slot not leased → `berth: <serial> is <state>, claim it first`;
  - no daemon → the usual `berth daemon unavailable: …` error.
- **Full control.** The scrcpy mirror always has input (no `--no-control`): the human has to type the login. Its window title is `<serial> <model>`, like a control mirror in `berth-bar`, and it passes `-s <serial>` and `--no-audio` like #22. DeviceHub always has input.
- **Returns at once.** The command exits 0 as soon as scrcpy is started or the URL is opened, with one stderr line: `berth: mirror open for <serial>, close the window when done`. It never waits for the window to close. Claude's shell times out after about 2 minutes, a login can take longer, and DeviceHub gives no exit to wait on. The agent asks the user in chat and waits for their reply.
- **Missing tools.** No scrcpy (same search as #22: `PATH`, then `/opt/homebrew/bin`, then `/usr/local/bin`) → exit 1, `berth: scrcpy not found: brew install scrcpy`. No app for `devices://` → exit 1, `berth: DeviceHub not found: needs Xcode 27`. Opening the URL fails → exit 1, `berth: mirror <udid> failed: <error>`. scrcpy output goes to `<Paths.logs>/mirror-<serial>.log`, the same file as `berth-bar` mirrors.
- **No tracking.** The CLI keeps no pid and no state. A release restarts the emulator, so adb loses it and scrcpy exits by itself (as in #22). DeviceHub keeps one window per simulator. Calling `berth mirror` twice on the same emulator, or clicking Mirror in `berth-bar` too, can open a second scrcpy window. This is accepted (YAGNI).
- **Discovery by Claude, three layers:**
  1. `docs/AGENTS.md` gets a section, "When a human must act on the device". It explains: claim with `berth claim` (not `berth run`, which releases the device when its command ends), run `berth mirror "$SERIAL"`, tell the user exactly what to do on the device, wait for their reply in chat, then continue. Do not release the device meanwhile, and run `berth renew` if the wait is long. The same text is the skill body (`claude-plugin/skills/berth/SKILL.md`), kept in sync by `PluginSyncTests`.
  2. The skill description gains triggers: login, sign-in, 2FA, captcha, show the emulator or simulator window, human action on a device.
  3. A new guard rule, `ScrcpyRule` in `Sources/berth/Guard/Rules/`, denies a direct `scrcpy` call with the hint `use berth mirror <serial>`. It allows `--version`, `-v`, `--help` and `-h`, as `EmulatorRule` does for its info flags. A scrcpy run by hand uses the `adb` on `PATH`, which can be a different adb version from the SDK one and restart the adb server that every agent shares. Claude also learns the command at the moment it reaches for scrcpy.
- **Where it lives.**
  - New `Sources/BerthCore/Mirror/` with `Scrcpy/` and `DeviceHub/` subfolders, following #29's layout in `Sources/BerthBar/Mirror/`. These pieces move there and become public: `ScrcpyLocator`, `ScrcpyArguments`, `MirrorMode`, `DeviceHubURL`, the `SimulatorMirrorOpener` protocol and `SystemSimulatorMirrorOpener` (NSWorkspace). BerthCore imports AppKit in the opener file only. The daemon links it but never calls it.
  - `Sources/BerthBar/Mirror/` keeps `MirrorController`, `MirrorEligibility` and its child-`Process` launcher, and imports the moved pieces. Its behavior is unchanged.
  - `Spawn.detached` gains an optional environment parameter (default: the current environment), so the CLI can pass `ADB`.
  - The CLI gets `Sources/berth/Commands/Mirror.swift` (ArgumentParser, registered in `Berth.swift`) and `Sources/berth/Mirror/` with a pure resolver (snapshot + serial → Android target, iOS target, or error) and the Android launcher on `Spawn.detached` behind a protocol, so tests use a fake.
- **Tests.**
  - Moved pieces: their existing tests move to `Tests/BerthCoreTests/Mirror/`.
  - Resolver in `Tests/berthTests/Mirror/`: leased Android → Android target; leased iOS → iOS target; free, booting, resetting and stopping slots → the `claim it first` error with the state; unknown serial → the `not a berth device` error.
  - Command flow with fakes: Android starts scrcpy with `-s <serial>`, `--no-audio`, title `<serial> <model>`, no `--no-control` and `ADB` in its environment; no scrcpy → the not-found error; iOS opens the DeviceHub URL; no DeviceHub → its error; an open failure → the failed error.
  - `ScrcpyRule` in the guard tests: `scrcpy -s emulator-5554` is denied with the hint, `scrcpy --version` is allowed, and `berth mirror emulator-5554` is allowed.
  - `PluginSyncTests` still pass with the new AGENTS.md section.
- **Runtime proof.** A real mirror opens a window, and that window takes focus. So the agent never opens one (`CLAUDE.md#Desktop proofs`). The agent proves the parts that open no window on a real daemon with a short `BERTH_HOME`: `berth mirror --help`, an unknown serial, a free slot, and the guard denying `scrcpy` from a hook payload on stdin. A human checks the real windows: a scrcpy window on a leased emulator that accepts input, a DeviceHub window on a leased simulator, and the scrcpy window closing on release.
- **Docs.** README: `berth mirror` in the CLI section, with scrcpy and Xcode 27 as optional dependencies. Wiki [[cli]] (command row, ScrcpyRule), [[claude-code]] (new rule, new skill triggers), [[architecture]] (`BerthCore/Mirror`, shared by the CLI and `berth-bar`).

## Acceptance criteria

- `swift build` and `swift test` pass.
- `berth mirror --help` describes the command, and `berth --help` lists it.
- `berth mirror <serial>` on a leased headless Android emulator, with scrcpy installed, opens a scrcpy window titled `<serial> <model>` that shows the emulator screen and accepts clicks and keys. The command exits 0 at once and prints `berth: mirror open for <serial>, close the window when done` on stderr.
- `berth mirror <udid>` on a leased iOS simulator, with Xcode 27, opens a DeviceHub window for that simulator that accepts input. The command exits 0 at once with the same stderr line.
- Opening the mirror does not reboot, erase or release the device, and its lease stays the same.
- When the device is released, the Android scrcpy window closes by itself.
- `berth mirror <serial>` on a free, booting, resetting or stopping slot exits 1 with `berth: <serial> is <state>, claim it first` and opens nothing.
- `berth mirror foo` exits 1 with `berth: foo is not a berth device`.
- Without scrcpy, `berth mirror` on an Android serial exits 1 with `berth: scrcpy not found: brew install scrcpy`. Without an app for `devices://` URLs, it exits 1 on an iOS UDID with `berth: DeviceHub not found: needs Xcode 27`.
- With no daemon running, `berth mirror` exits 1 and does not start the daemon.
- A Bash command `scrcpy -s emulator-5554`, given to `berth guard`, is denied (exit 2), and its stderr line names `berth mirror`. `scrcpy --version` and `berth mirror emulator-5554` are allowed.
- `docs/AGENTS.md` and the skill body explain the human-action flow with `berth mirror`, and the skill description names login, sign-in, 2FA and captcha.
- The `berth-bar` Mirror button (Android and iOS) behaves exactly as before.
- README documents `berth mirror` and its optional dependencies.

## Implementation

Round 1, 2026-10-20. One implementer, 3 bricks, rebased on main after #31 (#29) merged.

- Brick 1, shared mirror core in BerthCore:
  - `git mv` of `MirrorMode`, `ScrcpyArguments`, `ScrcpyLocator` to `Sources/BerthCore/Mirror/Scrcpy/`, and of `DeviceHubURL`, `SimulatorMirrorOpener`, `SystemSimulatorMirrorOpener` to `Sources/BerthCore/Mirror/DeviceHub/`. They are now public. Their tests moved to `Tests/BerthCoreTests/Mirror/`.
  - `Config.adbPath` (`<resolvedSDKRoot>/platform-tools/adb`) is the one home for the SDK adb path. `berth-bar`'s `SystemMirrorLauncher.defaultADB()` uses it.
  - `Spawn.detached` takes an optional `environment` (nil = inherit, as before). `SpawnTests` covers it.
- Brick 2, `berth mirror <serial>`:
  - `Sources/berth/Commands/Mirror.swift`, registered in `Berth.swift`. It reads a snapshot with `autoSpawn: false`.
  - `Sources/berth/Mirror/`: `MirrorTarget`, `MirrorError` (exact messages from the decisions), the pure `MirrorResolver`, the `AndroidMirrorLauncher` protocol with `SpawnMirrorLauncher` (detached scrcpy, `ADB` in env, log `mirror-<serial>.log`), and the `@MainActor` `MirrorFlow` with injectable locator, launcher, opener, adb and logs.
  - `Tests/berthTests/Mirror/`: resolver and flow tests with their own fakes. Test targets cannot share files, so the fake opener is a small copy of the `BerthBarTests` one.
- Brick 3, discovery:
  - `ScrcpyRule` is in `DeviceCommandGuard.defaultRules`. It denies `scrcpy` except `--version`, `-v`, `--help` and `-h`, and its reason names `berth mirror`. Guard tests cover direct and `sh -c` forms.
  - `docs/AGENTS.md` has a new section, "When a human must act on the device". The skill body is the same text, and the skill description now names login, sign-in, 2FA and captcha.
  - README: a `berth mirror` row under "Use" with its optional dependencies, and the guard bullet under "Claude Code" now names scrcpy.
- Notes:
  - Plain `swift test` fails on this Mac before any test runs: the Command Line Tools have no `TestingMacros` plugin. Tests run with `DEVELOPER_DIR=/Applications/Xcode-27.1.0.app/Contents/Developer swift test`.
  - `AndroidBackend` still builds its own adb path from its `sdk` variable. It does not read `Config`, so it was left as is.

## Review

Not run yet: `review.when: on_validation`, so the verifier runs at `/wa-validate`.

## Verification

Build ✅ (`swift build`). Tests ✅: the 4 suites pass, with berthTests 49, BerthBarTests 83, BerthCoreTests 44 and BerthDaemonTests 58 tests.

Runtime checks by the agent. No window was opened (`CLAUDE.md#Desktop proofs`):
- ✅ `berth mirror --help` describes the command, and `berth --help` lists `mirror`.
- ✅ With no daemon on `BERTH_HOME=/tmp/bm30`, `berth mirror foo` exits 1 with `berth: berth daemon unavailable: not running`. No daemon was started.
- ✅ With a daemon on `/tmp/bm30` and an empty pool, `berth mirror foo` exits 1 with `berth: foo is not a berth device`. That daemon was then stopped.
- ✅ The guard denies `scrcpy -s emulator-5554` (exit 2, and stderr names `berth mirror`). It allows `scrcpy --version` and `berth mirror emulator-5554` (exit 0).
- ✅ By unit tests with fakes:
  - free, booting, resetting and stopping slots give `claim it first`;
  - the scrcpy arguments, title and `ADB` env are right;
  - scrcpy not found, DeviceHub not found and open failure give their errors;
  - iOS opens the DeviceHub URL.
- Manual validation, not run by the agent: a real scrcpy window on a leased emulator that accepts input, a real DeviceHub window on a leased simulator, the scrcpy window closing on release, the lease staying the same, and the `berth-bar` Mirror button still working.

## Feedback
