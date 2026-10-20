# Architecture

One binary `berth`, two roles: short-lived **client** commands + long-lived **daemon**.

```
agent shell → berth claim/run/release/status/top (client, BerthCore.DaemonClient)
berth-bar (menu bar, read-only, BerthCore.DaemonWatch, never autospawn)
                 │ NDJSON over Unix socket  <BERTH_HOME>/berth.sock
                 ▼
            berth daemon run (BerthDaemon.Daemon)
              ├─ Server: SwiftNIO UDS, one task per connection
              ├─ Broker actor: slots, leases, FIFO waiters → [[broker]]
              ├─ DeviceBackend → DeviceRouter → AndroidBackend (emulator/adb) → [[android-backend]]
              │                              └ IOSSimulatorBackend (simctl) → [[ios-backend]]
              └─ reap loop every 5 s
```

## Modules
- `BerthCore` — shared by CLI, daemon, bar: `Model` (Slot, Lease, Owner, StateSnapshot), `Platform` (android | ios), `Protocol` (Request/Event enums, `Wire` JSON lines, `NewlineFrameDecoder`), `Client` (session, auto-spawn), `Config` (pool entry `avd` | `simulator`, `platform(of:)`, `models(for:)`), `Paths`, `Shell` (async Process runner), `Spawn` (posix_spawn detached), `ProcessInspector` (sysctl owner/liveness), `Watch` (`DaemonWatch` reconnecting watch stream), `Format` (`DurationFormat`), `Launchd` (`LaunchAgent`: per-user plist in `~/Library/LaunchAgents`, write/remove/isInstalled, no launchctl), `Version` (`BerthVersion.current`, stamped at release → [[release]]), `Update` (self-updater → [[update]]).
- `BerthBar` — `berth-bar` AppKit `NSStatusItem` + `NSPopover` (SwiftUI panel) app, BerthCore only. `App/` entry, `Status/` model + state, `MenuBar/` status item + label, `Panel/` views, `Login/` launch-at-login checkbox (`com.berth.bar` plist). Read-only toward daemon; `autoSpawn: false` (spawn would relaunch itself).
- `BerthDaemon` — `Broker`, `Server`, `Daemon` (lock, config, reap loop), `Backends/` (`DeviceBackend` protocol, `DeviceRouter`, `AndroidBackend`, `IOSSimulatorBackend`), `StateStore`, `SelfUpdate/` (auto update + same-pid re-exec → [[update]]).
- `berth` — ArgumentParser commands + TUI → [[cli]]; `Guard/` shell tokenizer + device rules for `berth guard` → [[claude-code]].
- `tools/desktop/desk.swift` — standalone script (outside package, `xcrun swift`): `desk-state`, `window-id <pid>`, `capture <pid>` (`screencapture -l`). Desktop proofs of `berth-bar` never take mouse/keyboard/focus → `CLAUDE.md#Desktop proofs`. Panel proven offscreen: `BerthBarTests/Panel` renders `StatusPanel` per state (`StatusModel.init(state:now:)`), `BERTH_PANEL_PNG_DIR` → PNGs. macOS 27: status item drawn by `MenuBarAgent`, not app pid → not capturable; popover open steals focus (`NSApp.activate`) → human checks click + Quit.

## Key decisions
- **Daemon auto-spawn**: no socket → client `posix_spawn`s `berth daemon run` w/ SETSID (outlives client, immune to terminal SIGHUP/SIGINT), retries connect 5 s. `flock` on `daemon.lock` → single daemon; loser exits 0.
- **Connection = claim lifetime**: claim open while queued; disconnect → waiter dropped. Grant needs `ack` before disconnect, else lease back to pool. → no leak if client killed mid-wait (Claude Bash 2 min timeout).
- **Persistence**: `state.json` rewritten each change; restart adopts slots w/ serial still in `adb devices` (free/leased kept, transitional stopped).
- **Paths**: `BERTH_HOME` relocates config/state/socket/logs (default `~/Library/Application Support/berth`, logs `~/Library/Logs/berth`). Socket path ≤ 104 bytes.
- **Shell output → temp files, not pipes**: adb may fork server inheriting pipe → read never EOF.
- **Login items = launchd agents, not `SMAppService`**: `berth-bar` bare executable, no `.app` bundle. Daemon `com.berth.daemon` (`berth daemon install`, KeepAlive, bootstrap now). Bar `com.berth.bar` (panel checkbox, RunAtLoad only, no KeepAlive → Quit sticks; no bootstrap/bootout → no 2nd instance, no self-kill). Checkbox on ⇔ plist exists. Plist keeps binary path + `BERTH_HOME` from when enabled. → #8
- Emulators spawned w/ `POSIX_SPAWN_CLOEXEC_DEFAULT` → no inherited daemon socket fds.

## Extending
- Platforms: one pool, queue, `maxRunning` for Android + iOS (eviction across platforms OK, same RAM). Broker knows platform only to filter claims. → [[ios-backend]]
- GUI: done → `BerthBar`.
