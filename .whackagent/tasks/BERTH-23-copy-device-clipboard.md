---
issue: BERTH-23
phase:
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
- The whole read has a 15 s timeout, like every other adb call of berth-bar.
- The pure parts are unit tested: the message encoder and decoder, the `scrcpy --version` parser, the server path lookup, the shell command line.
- If the scrcpy protocol of the installed version cannot be driven this way, the implementer stops with BLOCKED and the evidence. No other mechanism is invented.

### Button (autopilot assumption)

- A new column at the right end of the rows, after Mirror, on two kinds of rows:
  - Emulators section: Android slots in state `free` or `leased`, windowed or headless. A leased emulator is only read: no input, no wake.
  - Devices section: rows in adb state `device`, USB phones, Wi-Fi devices and unmanaged emulators alike.
- iOS rows get no button. `xcrun simctl pbpaste` would do it, but the ticket only asks for Android.
- Icon `doc.on.clipboard`, tooltip "Copy clipboard to Mac".
- Mac side: `NSPasteboard.general`, cleared, then set to the text as a plain string.
- One click, one read. Nothing is polled and nothing syncs in the background.
- Feedback in the panel caption, the same line the Kill and Wi-Fi buttons use:
  - success: "Copied clipboard of <serial>";
  - empty clipboard, or content that is not text: "<serial>: clipboard empty", and the Mac clipboard stays as it was;
  - scrcpy missing: the mirror text "scrcpy not found: brew install scrcpy";
  - any other failure: adb's or the server's own error line, or "<serial>: clipboard read timed out".

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

- [ ] Android emulator rows in state `free` or `leased` show a `doc.on.clipboard` button with the tooltip "Copy clipboard to Mac", in a new column after Mirror.
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
