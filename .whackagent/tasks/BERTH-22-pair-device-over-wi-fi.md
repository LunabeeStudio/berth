---
issue: BERTH-22
phase: review
type: feature
wiki: [architecture, glossary]
note: Ticket title covers the pair window only; scope grew in grill to Disconnect and USB to Wi-Fi buttons too.
created: 2026-11-27
---

## Context / Decisions

Ticket (user's words): "New action: handle the adb over wifi handshake flow".

berth already lists Wi-Fi devices under the berth-bar "Devices" section (BERTH-13): serials `ip:port` and `<name>._adb-tls-connect._tcp`. Getting a phone there still needs `adb pair` and `adb connect` typed by hand. This ticket adds three actions to berth-bar so a human does it from the panel.

Glossary: + `Wi-Fi device` | Never: wireless device, network device | Code: `isWifi`, `WifiAdb` | Means: phone adb reaches over the network, serial `ip:port` or mDNS name.

### Surface and architecture

- berth-bar only. No CLI command: pairing needs the phone in a human's hand, and agents never pair.
- berth-bar runs the SDK adb itself (`Config.adbPath`), like the Kill button (BERTH-17). No daemon request, no protocol change. The daemon shows the new Wi-Fi device on its next `adb devices -l` poll, as today.
- New feature folder `Sources/BerthBar/Wifi/`:
  - `WifiAdb` protocol (mDNS services, pair, connect, disconnect, tcpip, Wi-Fi address, devices) and its SDK adb implementation through `Shell.run`. Every adb call has a 15 s timeout.
  - Wi-Fi serial detection (`ip:port` or `._adb-tls-connect._tcp`) and button eligibility, pure and unit tested.
  - `Pair/`: flow controller (`@Observable`, state machine tested against a fake `WifiAdb`), window, QR payload and image, parser of `adb mdns services`.
- QR image comes from CoreImage (`CIQRCodeGenerator`). No new dependency.
- Prior art: Android Studio's "Pair devices using Wi-Fi" uses the same QR + mDNS flow; it is not reusable from a Swift app. No Swift library wraps it. The flow is a few adb calls, so berth drives adb directly.

### Pair window

- The panel actions row gets a "Pair device…" button next to "Launch emulator" and "Prepare AVD". It opens a small window titled "Pair device over Wi-Fi".
- A window, not the popover: the popover is `.transient` and closes on any click elsewhere, which would lose the flow while the human handles the phone.
- One window at a time. A second click brings it to the front. Closing the window cancels the flow.
- QR first. berth makes a random service name (`berth-<random>`) and password, and shows the QR `WIFI:T:ADB;S:<name>;P:<password>;;` with the phone steps (Developer options → Wireless debugging → Pair device with QR code).
- berth polls `adb mdns services` every 1 s for a `_adb-tls-pairing._tcp` service with that name, then runs `adb pair <ip>:<port> <password>`.
- The QR waits 2 min. After that the window shows "Phone not found: same Wi-Fi network? Try the pairing code." and a Retry button that makes a new name and password.
- "Use pairing code instead" shows two fields: the phone's `ip:port` and the 6-digit code. berth runs `adb pair <ip:port> <code>`. This path covers networks that block mDNS.
- Connect after a successful pair:
  1. Wait up to 10 s for adb's own mDNS auto-connect.
  2. Not listed yet: find the `_adb-tls-connect._tcp` service with the phone's IP in `adb mdns services`, run `adb connect <ip>:<port>`.
  3. Still nothing: the window asks for the "IP address & Port" shown on the phone's Wireless debugging screen and runs `adb connect`.
- Done = the serial is in `adb devices` with state `device`. The window shows "Connected <serial> <model>" and stays until closed.
- Errors: a failed `adb pair` or `adb connect` shows adb's own error line under the matching field. Typed fields are kept so the human fixes one.

### Disconnect button

- On Wi-Fi device rows only, in any adb state: a stale `offline` entry is the main reason to disconnect.
- It sits in the Kill column, which only emulator rows use. Icon `wifi.slash`, tooltip "Disconnect (adb disconnect)". No confirm, like Kill.
- berth-bar runs `adb disconnect <serial>`. Failure shows in the panel caption. The row leaves on the next poll.
- Risk: adb's mDNS auto-connect may reconnect a paired phone at once. The implementer checks this on a real phone. If it reconnects, the PR says so and the behavior is accepted.

### USB to Wi-Fi button

- On USB phone rows in state `device`: not an emulator, not a Wi-Fi serial. Same Kill column, icon `wifi`, tooltip "Switch to Wi-Fi".
- berth-bar reads the phone's address (`adb -s <serial> shell ip -f inet addr show wlan0`), runs `adb -s <serial> tcpip 5555`, waits up to 10 s, then runs `adb connect <ip>:5555`.
- Port is fixed at 5555, adb's default. No field.
- No address (Wi-Fi off): caption "<serial>: no Wi-Fi address, turn Wi-Fi on". Other failures show adb's line in the caption.
- The `<ip>:5555` row appears on the next poll. The USB row stays while the cable is in.
- This path also serves Android 10 and older, which cannot pair.

### Out of scope

- berth remembering paired phones to reconnect them: adb keeps pairing keys and reconnects by mDNS itself.
- A CLI command.
- Leasing Wi-Fi devices: devices stay seen, never leased (BERTH-13).

### Proof

- Unit tests against a fake `WifiAdb`: QR wait and its timeout, pair success and failure, the three connect steps, disconnect, USB switch with and without an address.
- Render tests (`BERTH_PANEL_PNG_DIR`) for the pair window states and the new row buttons.
- The agent runs the real adb calls against the USB phone connected to this Mac (`ip addr`, `tcpip`, `connect`, `disconnect`) from a test harness, never by clicking berth-bar (`CLAUDE.md#Desktop proofs`).
- A human checks the QR scan, the pairing code entry and the two buttons once.

## Acceptance criteria

- [ ] The panel shows a "Pair device…" button next to "Launch emulator" and "Prepare AVD".
- [ ] The button opens a "Pair device over Wi-Fi" window with a QR code and the phone steps. A second click brings the same window to the front.
- [ ] Scanning the QR from the phone's "Pair device with QR code" screen pairs the phone, and the window ends on "Connected <serial> <model>".
- [ ] The paired phone appears under Devices with state `device` within one poll.
- [ ] With no phone found for 2 min, the window shows "Phone not found: same Wi-Fi network? Try the pairing code." and Retry shows a new QR.
- [ ] "Use pairing code instead" with the phone's `ip:port` and code pairs and connects the phone.
- [ ] A wrong pairing code shows adb's error line and keeps both fields filled.
- [ ] When auto-connect and the mDNS lookup both fail, the window asks for the phone's "IP address & Port" and connects with it.
- [ ] Closing the window during the QR wait stops the `adb mdns services` polling.
- [ ] Wi-Fi device rows show a `wifi.slash` button. Clicking it removes the row on the next poll, or shows the failure in the caption. A row already gone from adb counts as disconnected, with no error. A phone paired by Wireless debugging comes back by itself within about 15 s: adb reconnects it.
- [ ] USB phone rows in state `device` show a `wifi` button. Clicking it makes an `<ip>:5555` row appear while the USB row stays.
- [ ] With the phone's Wi-Fi off, the `wifi` button shows "<serial>: no Wi-Fi address, turn Wi-Fi on".
- [ ] Emulator rows keep the Kill button only. USB rows in a state other than `device` show no new button.
- [ ] `swift build` and `swift test` pass. The pair window states and the new row buttons have render test PNGs.

## Implementation

Autopilot run, 2026-11-27. One implementer, 5 bricks.

1. Wi-Fi adb core (`Sources/BerthBar/Wifi/`): `WifiAdb` protocol, `SdkWifiAdb` (SDK adb through `Shell.run`, 15 s timeout per call), `WifiAdbError` (adb's own line), pure `AdbOutput` classifiers, `WifiAddress.parse`, `PhysicalDevice.isWifi`, `WifiEligibility`, `MdnsService` and its `adb mdns services` parser. `DeviceListing` moved from BerthDaemon to `BerthCore/Android/` so berth-bar parses `adb devices -l` with the same code.
2. Row buttons: `WifiDeviceActions` (`disconnect`, `switchToWifi`: address, `tcpip 5555`, then `connect <ip>:5555` retried up to 10 times, 1 s apart; caption on failure). `DeviceRow` Kill column shows Kill, `wifi.slash` or `wifi`. Caption shown in `StatusPanel`.
3. Pair flow: `PairQR` (random `berth-` name and password, `WIFI:T:ADB;S:…;P:…;;`), `PairFlow` state machine (QR wait of 120 polls 1 s apart, not found, pairing code, pairing, connecting, manual connect, connected). Connect after pair: 10 polls of `adb devices` for the phone, then the `_adb-tls-connect._tcp` service with the phone's IP, then manual entry. A failed QR pair falls back to the pairing code screen with the address prefilled.
4. Window: `PairQRImage` (CoreImage, crisp modules, quiet zone), `PairCopy`, `PairView`, `PairWindowController` (one window, second open brings it to front, close cancels the flow), `AppKitPairWindow` (plain `NSWindow`). "Pair device…" button always shown in the actions row (`AVDMenus`).
5. Proof: opt-in `RealPhoneWifiTests` (`BERTH_WIFI_PHONE=<usb serial>`), render PNGs, app start check.

Build: `swift build` complete, 0 new warnings. Tests: `swift test` 63 + 147 + 82 + 156 passed.

## Review

### validation (autopilot), 2026-11-27

Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. No tools configured. No specialist reviewer (no Swift one in the session). 2 verifier rounds, 1 autofix round.

Round 1: 11 minor findings.
- fixed: the phone after a pair is matched by the guid adb prints (`[guid=…]`), not by "any new Wi-Fi device". A second phone connecting at the same time is no longer taken for this one.
- fixed: the 2 min QR wait and the 10 s device waits use a clock deadline (`PairClock`), so a slow adb no longer stretches them.
- fixed: Return submitted the pairing code twice (`.onSubmit` and the default button). Only the default button is left.
- fixed: `start()` does nothing outside the QR state, so it can no longer cancel a running pair.
- fixed: the error line lives in the `codeEntry` and `manualConnect` states instead of a separate property.
- fixed: member order, a test in the wrong suite, a repeated type name.
- fixed: window files moved to `Wifi/Pair/Window/`. `AVDMenus` renamed `PanelActions`, since it now holds the Pair button too.
- half: disconnect of an mDNS-named row (below). An opt-in real phone test was added (`BERTH_WIFI_MDNS_SERIAL`).

Round 2: 10 closed, 1 open.
- open, 🟠 major: `WifiEligibility.swift:5` shows Disconnect on `adb-…._adb-tls-connect._tcp` rows, the rows a QR pair creates. `adb disconnect adb-foo._adb-tls-connect._tcp` answered `error: no such device 'adb-foo._adb-tls-connect._tcp:5555'`: adb appends `:5555` to a name without a port. If adb also does this for a connected mDNS device, the button only ever shows an error caption on those rows. The verifier asks to hide the button there. Not applied by autopilot: the acceptance criteria ask for the button on every Wi-Fi device row and accept a failure caption. Not proven either way: no paired phone was connected.

## Verification

- `swift build` and `swift test` pass on all four targets. Real phone test skipped without `BERTH_WIFI_PHONE`.
- Render PNGs read by the implementer: `pair-qr`, `pair-qr-dark`, `pair-not-found`, `pair-code-error`, `pair-connecting`, `pair-manual-error`, `pair-connected`, `pair-connected-dark`, `live-devices` (`wifi` on the USB `device` row, `wifi.slash` on both Wi-Fi rows, Kill on emulator rows only, nothing on USB `offline` and `unauthorized` rows), `live-devices-wifi-caption`, `live-empty` and `live-avd-menus` (Pair device button).
- `PairQRImageTests` decodes the QR image back to the exact payload with CIDetector.
- Real `adb mdns services` output captured on adb 37.0.3: tab separated, service type without a trailing dot. The parser accepts it.
- berth-bar built from this branch starts with `BERTH_HOME=/tmp/bb22`, stays alive, and the frontmost app does not change (`desk-state` before and after identical). Stopped by pid.
- Real phone run, after the phone was plugged back in: `BERTH_WIFI_PHONE=R3CT312YV5B swift test --filter RealPhoneWifiTests` passed. `wifiAddress` gave `192.168.4.29`. After Switch to Wi-Fi, `adb devices` listed `192.168.4.29:5555` and `R3CT312YV5B`, both `device`. Disconnect removed `192.168.4.29:5555`, and it stayed gone for 10 s: no auto-reconnect. `adb -s R3CT312YV5B usb` put the phone back in USB mode.
- `adb mdns services` listed nothing while the phone was in `tcpip` mode: only paired phones advertise `_adb-tls-connect._tcp`.
- Not run: disconnect of an mDNS-named row (`BERTH_WIFI_MDNS_SERIAL`). It needs a phone paired by QR code.
- Left to a human: QR scan, pairing code entry, both row buttons clicked in the panel, typing and resizing in the pair window.

### Feedback round 1

- `BERTH_WIFI_MDNS_SERIAL=adb-R3CT312YV5B-kWl1wg._adb-tls-connect._tcp swift test --filter RealPhoneWifiTests` passed on the S22. Two disconnects in a row through `WifiDeviceActions` both left the caption empty. The phone came back within 10 s by adb's mDNS auto-connect.
- `swift build` and `swift test` pass: 63 + 147 + 82 + 164 tests, 0 new warnings.

## Feedback

### Round 1 — 2026-11-27

Asked: "disconnect: treat "no such device" as already gone; note in PR that a paired phone auto-reconnects within ~15 s".

Triage: both adjustments.

Evidence, captured on the S22 connected by Wireless debugging (`adb-R3CT312YV5B-kWl1wg._adb-tls-connect._tcp`):
- `adb disconnect <mDNS name>` works: `disconnected …`, exit 0. The open verifier finding guessed it would fail. It does not.
- The same command right after answers `error: no such device '<name>:5555'`, exit 1. The panel row lags adb by up to one poll, so a click on a row adb already dropped showed that error. The human saw it on the first click.
- adb reconnects a paired phone by itself 8 to 15 s after a disconnect.

Changed:
- `SdkWifiAdb.disconnect` treats adb's `no such device` answer as success: the device is already gone (`AdbOutput.reportsNoSuchDevice`, unit tested with the real line).
- The opt-in mDNS test disconnects twice in a row and expects no caption.
- The Disconnect criterion now says a row already gone counts as disconnected, and that a paired phone comes back within about 15 s.

Warnings: none. Review: deferred to `/wa-validate`. Verify: real run on the S22 passed.
