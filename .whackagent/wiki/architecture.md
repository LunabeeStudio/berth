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
- `BerthCore` — shared by CLI, daemon, bar: `Model` (Slot, Lease, Owner, StateSnapshot), `Platform` (android | ios), `Protocol` (Request/Event enums, `Wire` JSON lines, `NewlineFrameDecoder`), `Client` (session, auto-spawn), `Config` (pool entry `avd` | `simulator`, `platform(of:)`, `models(for:)`), `Paths`, `Shell` (async Process runner), `Spawn` (posix_spawn detached), `ProcessInspector` (sysctl owner/liveness), `Watch` (`DaemonWatch` reconnecting watch stream), `Format` (`DurationFormat`).
- `BerthBar` — `berth-bar` AppKit `NSStatusItem` + `NSPopover` (SwiftUI panel) app, BerthCore only. `App/` entry, `Status/` model + state, `MenuBar/` status item + label, `Panel/` views. Read-only; `autoSpawn: false` (spawn would relaunch itself).
- `BerthDaemon` — `Broker`, `Server`, `Daemon` (lock, config, reap loop), `Backends/` (`DeviceBackend` protocol, `DeviceRouter`, `AndroidBackend`, `IOSSimulatorBackend`), `StateStore`.
- `berth` — ArgumentParser commands + TUI → [[cli]].

## Key decisions
- **Daemon auto-spawn**: no socket → client `posix_spawn`s `berth daemon run` w/ SETSID (outlives client, immune to terminal SIGHUP/SIGINT), retries connect 5 s. `flock` on `daemon.lock` → single daemon; loser exits 0.
- **Connection = claim lifetime**: claim open while queued; disconnect → waiter dropped. Grant needs `ack` before disconnect, else lease back to pool. → no leak if client killed mid-wait (Claude Bash 2 min timeout).
- **Persistence**: `state.json` rewritten each change; restart adopts slots w/ serial still in `adb devices` (free/leased kept, transitional stopped).
- **Paths**: `BERTH_HOME` relocates config/state/socket/logs (default `~/Library/Application Support/berth`, logs `~/Library/Logs/berth`). Socket path ≤ 104 bytes.
- **Shell output → temp files, not pipes**: adb may fork server inheriting pipe → read never EOF.
- Emulators spawned w/ `POSIX_SPAWN_CLOEXEC_DEFAULT` → no inherited daemon socket fds.

## Extending
- Platforms: one pool, queue, `maxRunning` for Android + iOS (eviction across platforms OK, same RAM). Broker knows platform only to filter claims. → [[ios-backend]]
- GUI: done → `BerthBar`.
