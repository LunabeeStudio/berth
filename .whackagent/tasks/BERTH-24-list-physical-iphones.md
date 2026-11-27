---
issue: BERTH-24
phase:
type: feature
wiki: [architecture, ios-backend, glossary]
note: Open PR #84 (BERTH-23) also edits StatusPanel.swift, PanelColumns.swift and StatusPanelRenderTests.swift. Merge conflicts there are likely.
created: 2026-11-27
---

## Context / Decisions

Ticket (card description): the berth-bar "Devices" section (BERTH-13) only lists Android phones from `adb devices -l`. A plugged-in iPhone is never shown.

Grilled unattended by `/wa-autopilot` on 2026-11-27. Decisions tagged `(autopilot assumption)` are for the user to confirm or correct. The other decisions come from the card.

### From the card

- List only, like BERTH-13 for Android: one row per iPhone with its name, model, iOS version and state. No claim, release or mirror. The Wi-Fi, Kill and mirror buttons stay hidden on these rows.
- Source: usbmuxd directly (`/var/run/usbmuxd`), not `xcrun devicectl`. `ListDevices` gives the UDID. A `Connect` to lockdownd (port 62078) and an unauthenticated `GetValue` give `DeviceName`, `ProductType` and `ProductVersion`. No Xcode or third-party dependency.
- Why not `devicectl`: Xcode 27 no longer handles iOS 16 phones. An iPhone X (iOS 16.5.1) appears there only as `iPhone10,6`, with no name and `pairingState: unsupported`.
- USB connections only. iPhones that usbmuxd sees over Wi-Fi sync are left out, to avoid noise.
- The lockdown values are read once per attachment, cached by usbmuxd `DeviceID`, not on every 5 s reap tick.
- iPhones are listed whatever the pool holds. A failed usbmuxd poll keeps the last list and never breaks the Android listing.
- Proven: a standalone Swift prototype read "Lunabee iPhone X Tom", `iPhone10,6`, iOS 16.5.1 from a USB iPhone X through usbmuxd and lockdown, without a trusted session.

### Where it lives

- The daemon polls usbmuxd and publishes the list in `StateSnapshot`, like the Android devices. berth-bar keeps getting everything from the daemon watch, and one process polls. (autopilot assumption)
- New snapshot field `iosDevices: [IOSDevice]`, read with `decodeIfPresent`, so an older daemon or client still works. It is separate from `devices`: the Kill, Wi-Fi and mirror rules read `PhysicalDevice` serials and adb states, and an iPhone row must never match them. (autopilot assumption)
- `IOSDevice` is a value type in `BerthCore`: UDID, name, product type, OS version (each optional except the UDID), and whether this Mac trusts it. (autopilot assumption)
- The usbmuxd client lives in a new daemon folder `Sources/BerthDaemon/Usbmux/`: socket framing (16-byte header, XML plist through `PropertyListSerialization`), `ListDevices`, `ReadPairRecord`, `Connect`, and the lockdown `GetValue` exchange (4-byte big-endian length, XML plist). It sits behind a small protocol (`IOSDeviceSource`, one call that returns the list or nil on failure) injected into the broker, so broker tests use a fake. (autopilot assumption)
- The broker polls the source on every reap tick, beside `backend.listing()`, and calls `changed()` when the list differs. It also fills the list at restore. `ListDevices` and `ReadPairRecord` are cheap local socket calls; only the lockdown values are cached. (autopilot assumption)
- Every socket call has a short timeout (2 s), so a hung usbmuxd or phone never stalls the reap tick. (autopilot assumption)

### What the row shows

- Every USB device usbmuxd reports is listed, iPads included. Filtering on device class needs one more lockdown value for no gain. (autopilot assumption)
- Glossary: + `iOS device` | Never: Apple device, iDevice | Code: `IOSDevice` | Means: iPhone or iPad berth sees through usbmuxd over USB. (autopilot assumption)
- iOS device rows come after the Android rows, in the same "Devices" section, in a new `IOSDeviceRow` view. They use the `PanelColumns` widths: name in the serial column (UDID in the hover help), product type in the model column (`iPhone10,6`, raw, like the raw Android model), then `iOS <version> · <state>` in the detail span. A missing value shows `—`. (autopilot assumption)
- State: `trusted` when usbmuxd holds a pair record for the UDID (`ReadPairRecord` succeeds), else `not trusted`. The words match the phone's "Trust This Computer?" prompt. The pair record is read on every tick, so tapping Trust on the phone shows within one poll. A trust revoked on the phone side still shows `trusted`: accepted. (autopilot assumption)
- A lockdown failure (phone still booting, locked out) keeps the row with `—` values and retries at the next attachment only. (autopilot assumption)
- "none connected" shows only when there is neither an Android nor an iOS device.

### Out of scope

- `berth status` human table and the TUI stay unchanged. `berth status --json` carries the new field, since it prints the snapshot.
- iOS devices never become slots, never appear in `berth claim` grants, never count against `maxRunning`.
- Marketing names (`iPhone X` for `iPhone10,6`): no mapping table.
- Network (Wi-Fi sync) devices.

### Proof

- Unit tests against fixed usbmuxd and lockdown plist payloads (parse `ListDevices`, keep USB only, `GetValue` replies), and broker tests against a fake `IOSDeviceSource`: published list, cache per `DeviceID`, failed poll keeps the last list, Android devices unaffected, never slots or grants.
- Render test (`BERTH_PANEL_PNG_DIR`) for a snapshot with Android and iOS device rows, light and dark.
- Runtime: own daemon (`BERTH_HOME` short dir), `berth status --json` shows the iOS device when one is plugged in over USB. No iPhone was plugged into this Mac at grill time; without one, the agent proves the usbmuxd `ListDevices` call returns an empty list without error, and a human checks the real row.

## Acceptance criteria

- [ ] With an iPhone plugged in over USB, the berth-bar "Devices" section shows a row with its name, model (`iPhone10,6`), iOS version and state, within one poll.
- [ ] The iPhone row has no mirror, Kill or Wi-Fi button.
- [ ] The state reads `trusted` when this Mac holds a pair record for the phone, else `not trusted`.
- [ ] Unplugging the iPhone removes its row within one poll.
- [ ] An iPhone usbmuxd sees only over Wi-Fi sync is not listed.
- [ ] The lockdown values are read once per attachment, not on every tick.
- [ ] When usbmuxd fails, the last iOS list stays and Android devices are still listed.
- [ ] A snapshot without the new field decodes, with no iOS device.
- [ ] `berth claim` never grants an iOS device, and `berth status` human output is unchanged.
- [ ] The panel render test covers Android and iOS device rows; `swift build` and `swift test` pass.

## Implementation

## Review

## Verification

## Feedback
