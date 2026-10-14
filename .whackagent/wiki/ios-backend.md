# iOS backend

`IOSSimulatorBackend: DeviceBackend` (BerthDaemon/Backends/IOSSimulatorBackend.swift). All calls = `xcrun simctl` via `Shell.run`. Added by #2.

## Config
Pool entry `{"simulator": "iPhone 17", "maxInstances": 2}` — value = simctl device type (name or id), runtime = simctl default (newest compatible). Never auto-added on first run: opt-in. Model name shared namespace with AVDs → must not collide.

## Owned devices
- Daemon start (`provision()`, before `broker.restore()`): per iOS entry ensure `berth-<simulator>-<k>`, k = 1…maxInstances, exist (`simctl create`). Kept across leases + daemon runs (no clone churn).
- `owned` UDID set = every `berth-` device found or created. Launch/erase/boot/shutdown refuse anything else → user's simulators never touched (even booted ones).
- Create fails (bad device type) / `simctl list` fails → `unavailableReason(model:)` set → broker fails claims fast with simctl's message, never queues forever.

## Lifecycle
- Serial = UDID (what `xcodebuild -destination id=…` + `simctl` take). No pid tracked (nil).
- Launch = `shutdown` (errors ignored) + `erase` + `boot`. Headless: Simulator.app never opens.
- Ready = `simctl bootstatus`, bounded by `bootTimeoutSeconds` → `BackendError.bootTimeout`.
- Reset = launch + waitReady → every lease factory-clean. Template state not kept (re-clone would change UDID).
- Live = booted `berth-` devices; simctl failure → nil (unknown).
- Measured (iOS 27, iPhone 17): first claim ≈ 20 s, reset ≈ 24 s (vs Android ≈ 5 s).

## Routing
`DeviceRouter` (struct) wraps Android + iOS backends: model calls by `Config.platform(of:)`, serial-only calls by shape (`emulator-<port>` = Android, else iOS). `liveSerials` queries only platforms in pool; any nil → nil, so transient adb/simctl failure never stops slots. Daemon runs `adb start-server` only with Android entries. See [[broker]], [[architecture]].
