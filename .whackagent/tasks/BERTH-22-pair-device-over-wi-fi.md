---
issue: BERTH-22
phase:
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
- [ ] Wi-Fi device rows show a `wifi.slash` button. Clicking it removes the row on the next poll, or shows the failure in the caption.
- [ ] USB phone rows in state `device` show a `wifi` button. Clicking it makes an `<ip>:5555` row appear while the USB row stays.
- [ ] With the phone's Wi-Fi off, the `wifi` button shows "<serial>: no Wi-Fi address, turn Wi-Fi on".
- [ ] Emulator rows keep the Kill button only. USB rows in a state other than `device` show no new button.
- [ ] `swift build` and `swift test` pass. The pair window states and the new row buttons have render test PNGs.

## Implementation

## Review

## Verification

## Feedback
