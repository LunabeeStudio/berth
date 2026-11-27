---
issue: BERTH-23
phase: validated
type: feature
wiki: [architecture, glossary]
note: Grilled by autopilot, nobody present. Every decision below tagged (autopilot assumption) waits for the user's confirmation.
created: 2026-11-27
---

## Context / Decisions

Ticket (user's words): "Add button to copy clipboard content of emulator and real android device to macos clipboard".

Today a human who copies text on an emulator or a phone has no way to get it on the Mac, unless a scrcpy mirror window is open (scrcpy syncs the clipboard itself). This ticket adds a button to berth-bar rows that copies the device's clipboard text to the Mac clipboard.

### How berth reads the device clipboard (autopilot assumption)

- Android has no shell command for the clipboard. `adb shell cmd clipboard` answers `No shell command implementation.` on the S22 (Android 16), and `dumpsys clipboard` prints nothing.
- A raw binder call (`service call clipboard …`) was tried on the S22 and failed: the arguments and transaction codes change per Android version and per vendor. Rejected.
- berth uses the scrcpy server, the same one berth-bar already runs for mirrors. scrcpy reads the clipboard as the shell user on every Android version scrcpy supports, phones and emulators alike.
- Flow, all through the SDK adb (`Config.adbPath`), never the adb on `PATH`:
  1. Find the server: `SCRCPY_SERVER_PATH` when set, else `<scrcpy dir>/../share/scrcpy/scrcpy-server` next to the binary `ScrcpyLocator` finds. Read the version from `scrcpy --version` (first line, `scrcpy 5.0.1`): the server refuses a client of another version.
  2. `adb -s <serial> push <server> /data/local/tmp/berth-scrcpy-server.jar`. A berth path, not scrcpy's own, so a running mirror's push is never overwritten.
  3. `adb -s <serial> forward tcp:0 localabstract:scrcpy_<scid>`, with a random 31-bit `scid` in 8 hex digits.
  4. Start the server: `adb -s <serial> shell CLASSPATH=/data/local/tmp/berth-scrcpy-server.jar app_process / com.genymobile.scrcpy.Server <version> scid=<scid> log_level=warn tunnel_forward=true video=false audio=false control=true power_on=false cleanup=false clipboard_autosync=false`. Exact option names come from the scrcpy source of the installed version. `power_on=false` keeps a sleeping phone's screen off.
  5. Connect to `127.0.0.1:<port>`, read the dummy byte, send the control message `GET_CLIPBOARD` with copy key `none`, read the device message `CLIPBOARD` (type, length, UTF-8 text).
  6. Close the socket, stop the server process, `adb forward --remove tcp:<port>`, every time, success or failure.
- The whole click is bounded by 15 s: 12 s for the read, then 3 s shared by the cleanup steps.
- The pure parts are unit tested: the message encoder and decoder, the `scrcpy --version` parser, the server path lookup, the shell command line.
- If the scrcpy protocol of the installed version cannot be driven this way, the implementer stops with BLOCKED and the evidence. No other mechanism is invented.

### Button (autopilot assumption)

- A new column at the right end of the rows, after Mirror, on two kinds of rows:
  - Emulators section: Android slots in state `free` or `leased`, windowed or headless. A leased emulator is only read: no input, no wake.
  - Devices section: rows in adb state `device`, USB phones, Wi-Fi devices and unmanaged emulators alike.
- iOS rows get no button. `xcrun simctl pbpaste` would do it, but the ticket only asks for Android.
- Icon `square.on.square`, tooltip "Copy clipboard to Mac".
- Mac side: `NSPasteboard.general`, cleared, then set to the text as a plain string.
- One click, one read. Nothing is polled and nothing syncs in the background.
- Feedback in the panel caption, the same line the Kill and Wi-Fi buttons use:
  - success: "Copied clipboard of <serial>";
  - empty clipboard, or content that is not text: "<serial>: clipboard empty", and the Mac clipboard stays as it was;
  - scrcpy missing: the mirror text "scrcpy not found: brew install scrcpy";
  - any other failure: adb's or the server's own error line, or "<serial>: clipboard read timed out".
- While a read runs, the caption shows "Reading clipboard of <serial>…". A second click on the same row waits for the running read and starts no second one. (Added at validation: an empty clipboard takes about 3 s to answer.)

### Architecture (autopilot assumption)

- berth-bar only. No CLI command and no daemon request: a human copies on the device, a human pastes on the Mac. No protocol change.
- New feature folder `Sources/BerthBar/Clipboard/`:
  - `DeviceClipboard` protocol (`text(serial:) async throws -> String?`) and its scrcpy implementation.
  - `MacPasteboard` protocol and its `NSPasteboard` implementation, so the action is tested without touching the real clipboard.
  - `ClipboardActions` (`@Observable`, `@MainActor`, a `caption` like `WifiDeviceActions`).
  - `ClipboardEligibility`, pure and tested, like `MirrorEligibility`.
- Server path and version lookup next to `ScrcpyLocator` in `BerthCore/Mirror/Scrcpy/` when that reads better there.

### Out of scope

- Mac to device (paste the Mac clipboard on the device). scrcpy's mirror window already does it.
- Images and other non-text clips: scrcpy only carries text.
- iOS simulators.
- A CLI command for agents.

### Proof

- Unit tests: message codec, version and path lookup, eligibility, `ClipboardActions` captions against a fake `DeviceClipboard` and a fake `MacPasteboard`.
- Render test PNGs (`BERTH_PANEL_PNG_DIR`) of the rows with the new button and of the caption.
- Real devices, from an opt-in test harness, never by clicking berth-bar (`CLAUDE.md#Desktop proofs`). The harness reads the clipboard through `ScrcpyDeviceClipboard` and never writes the Mac clipboard:
  - an emulator leased with berth: set its clipboard first with `adb -s <serial> shell cmd clipboard` if it exists there, else by typing text in a field and copying it with `adb shell input`;
  - the USB phone connected to this Mac, read only.
- A human clicks the button once on an emulator and once on a phone, then pastes on the Mac.

## Acceptance criteria

- [ ] Android emulator rows in state `free` or `leased` show a `square.on.square` button with the tooltip "Copy clipboard to Mac", in a new column after Mirror.
- [ ] Device rows in adb state `device` show the same button. Device rows in other states and iOS rows show none.
- [ ] Clicking it on an emulator whose clipboard holds text puts that exact text on the Mac clipboard, and the caption shows "Copied clipboard of <serial>".
- [ ] Clicking it on a real phone, USB or Wi-Fi, does the same.
- [ ] Text with accents, emoji and several lines arrives unchanged.
- [ ] With an empty device clipboard, the caption shows "<serial>: clipboard empty" and the Mac clipboard keeps its content.
- [ ] Without scrcpy installed, the caption shows "scrcpy not found: brew install scrcpy".
- [ ] A read that hangs ends after 15 s with a caption, and leaves no adb forward and no server process behind.
- [ ] A sleeping phone's screen stays off during the read.
- [ ] An open mirror of the same device keeps working during and after the read.
- [ ] `swift build` and `swift test` pass. The rows with the new button and the caption have render test PNGs.

## Implementation

Autopilot run, 2026-11-27. One implementer, 2 bricks.

1. Device clipboard read (`Sources/BerthBar/Clipboard/`): `DeviceClipboard` protocol and `ScrcpyDeviceClipboard`. It pushes the installed scrcpy server to `/data/local/tmp/berth-scrcpy-server.jar`, forwards `localabstract:scrcpy_<scid>`, starts the server with video, audio, power on, cleanup and clipboard autosync off, then sends `GET_CLIPBOARD` and reads the `CLIPBOARD` reply. Wire codec in `Scrcpy/Wire/`, server command line and process in `Scrcpy/Server/`, adb and scrcpy calls behind `CommandRunner`. `ScrcpyServerLocator` (`SCRCPY_SERVER_PATH`, else `../share/scrcpy/scrcpy-server` next to the binary) and `ScrcpyVersion` in `BerthCore/Mirror/Scrcpy/`.
2. Row button: `ClipboardEligibility`, `ClipboardActions` (caption, one read per serial at a time), `MacPasteboard` and `SystemMacPasteboard` (`NSPasteboard.general`), `Panel/ClipboardButton` in a new column after Mirror. The panel is 680 pt wide instead of 650.

Facts found while building:
- scrcpy 5.0.1 also needs `send_device_meta=false`, or it sends a 64-byte device name after the dummy byte.
- With autosync off, the server sends no reply when the clip has no text. berth waits 3 s after `GET_CLIPBOARD`, then counts silence as empty.
- The server takes one control connection. adb accepts a connection before the server listens and then drops it, so berth retries a connection that closes.
- A timeout during server start leaves `app_process` waiting on `accept()`. Cleanup then kills it on the device by its scid (`pkill -f 'com.genymobile.[s]crcpy.Server .*scid=<scid>'`), so a mirror's server is never touched.
- `adb forward --remove` needs `-s <serial>` when several devices are connected.

Build: `swift build` complete, 0 new warnings. Tests: `swift test` 63 + 147 + 91 + 228 passed.

## Review

### validation (autopilot), 2026-11-27

Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. No tools configured. No specialist reviewer. 3 verifier rounds, 2 autofix rounds. Verdict: clean. 0 withdrawn, 0 disputed.

Round 1: 13 minor findings, all fixed.
- The caption waited for cleanup, so a hang could take about 30 s. Now the read gets 12 s and cleanup shares 3 s.
- A hanging `scrcpy --version` now reports a timeout.
- New "Reading clipboard of <serial>…" caption. A second click on the same serial reuses the running read.
- The receive logic and the cleanup on each failure point are unit tested: `ScrcpyControlChannel`, `CommandRunner` and `ScrcpyServerLauncher` are injected.
- `Clipboard/` split into `Pasteboard/`, `Scrcpy/Wire/` and `Scrcpy/Server/`. One `ClipboardButton` shared by both rows.
- YAGNI and style fixes: `decode` returns the message only, `.init` forms, explicit types, one restating comment removed.

Round 2: 4 minor findings, all fixed: `CommandRunner` moved to `Scrcpy/`, a `var` turned into a `let`, a test fake made thread safe with `Mutex`, temporary test folders removed.

Round 3: clean.

### validation, 2026-11-27 (after feedback round 1)

Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. No tools configured, no open build warnings. 2 verifier rounds, 1 autofix round. Verdict: clean. 0 withdrawn, 0 disputed.
- The inline hunks of feedback round 1 were judged clean: the icon is `square.on.square` everywhere, and the `EmulatorRow` placeholders fix the windowed row.
- fixed, 🟡 minor: `DeviceRow` built its Mirror and clipboard columns with a plain `.frame`, so it stayed aligned only because both buttons share the same rule. Both columns now use the `Color.clear` placeholder with the button as overlay, like the Kill column and `EmulatorRow`.
- Code moved after the user's test: `Sources/BerthBar/Panel/DeviceRow.swift`.

## Verification

- `swift build` and `swift test` pass on all four targets. The real device tests skip without `BERTH_CLIPBOARD_SERIAL`.
- Emulator `emulator-5554` (Android 17), leased with berth and released. A 34-character, 63-byte text with accents, emoji, CJK and line breaks came back identical in 0.2 to 0.4 s, after every autofix round. An empty clipboard gave nil. The click path through `ClipboardActions` into a fake pasteboard showed "Copied clipboard of emulator-5554" with one write.
- USB S22 `R3CT312YV5B`, read only: 72 characters read in 0.5 to 0.9 s. Its screen state stayed `Awake` before and after.
- Wi-Fi Pixel 9 Pro, read only: an empty clipboard gave nil after about 3.7 s, and the caption "<serial>: clipboard empty" with no pasteboard write.
- Reads with timeouts of 20 to 220 ms hit every phase on the three devices. Each ended with the timeout caption or a normal read. `adb forward --list` and the device's process list showed no forward and no server left.
- Render PNGs checked: `live-clipboard`, `live-clipboard-dark`, `live-clipboard-caption`, `live-clipboard-caption-error`, `live-clipboard-caption-reading`. The button shows on Android `free`, `leased` and windowed rows and on devices in state `device`. It does not show on iOS, `booting`, `offline` or `unauthorized` rows.
- berth-bar built from this branch starts with `BERTH_HOME=/tmp/bb23` and stays alive, with an empty log. The frontmost app did not change. It was stopped by pid.
- Not run on a device: a sleeping phone during a read (all devices were awake; the server runs with `power_on=false` and berth sends no input), and a read while a mirror of the same device is open (a hook blocks scrcpy in the agent's shell).
- Left to a human: one click on an emulator row and one on a phone row, then a paste on the Mac.
- Seen once, not reproduced: right after a series of timed out reads, one read got an empty reply while the emulator's clipboard held text.

### Feedback round 1

- `swift build` and `swift test` pass: 63 + 147 + 91 + 228 tests, 0 new warnings.
- Render PNG `live-clipboard` checked: the `square.on.square` button shows on the same rows as before. On the windowed row, which has no Mirror button, the clipboard button now stays in its own column.
- Not run on a device: the change is an icon and the row layout.

### validation, after feedback round 1

- `swift build` and `swift test` pass: 63 + 147 + 91 + 228 tests, 0 new warnings.
- Render PNGs `live-clipboard` and `live-clipboard-dark` checked after the `DeviceRow` fix: device and emulator rows aligned, no button on `offline` or `unauthorized` rows.

## Feedback

### Round 1 — 2026-11-27

Asked: "find more modern icon for copy". The user picked `square.on.square` from rendered candidates (`document.on.document`, `square.on.square`, `square.and.arrow.down.on.square`, `arrow.right.doc.on.clipboard`).

Triage:
- adjustment: the button icon changes from `doc.on.clipboard` to `square.on.square`. The first criterion and the wiki now name it.
- defect, found in the render while checking the icon: on a windowed emulator row, which has no Mirror button, the clipboard button moved left into the Mirror column. Empty Mirror and clipboard columns on emulator rows now keep their width (`EmulatorRow`).

Changed, both inline (written by the main thread, no implementer):
- `Sources/BerthBar/Panel/ClipboardButton.swift`: icon `square.on.square`.
- `Sources/BerthBar/Panel/EmulatorRow.swift`: the Mirror and clipboard columns are `Color.clear` frames with the button as overlay, like the Kill column of `DeviceRow`.

Warnings: none. Review: deferred to `/wa-validate`. Verify: render PNG checked.
