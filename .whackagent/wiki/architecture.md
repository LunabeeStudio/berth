# Architecture

One binary `berth`, two roles: short-lived **client** commands + long-lived **daemon**.

```
agent shell → berth claim/run/release/status/top (client, BerthCore.DaemonClient)
                 │ NDJSON over Unix socket  <BERTH_HOME>/berth.sock
                 ▼
            berth daemon run (BerthDaemon.Daemon)
              ├─ Server: SwiftNIO UDS, one task per connection
              ├─ Broker actor: slots, leases, FIFO waiters → [[broker]]
              ├─ DeviceBackend → AndroidBackend (emulator/adb) → [[android-backend]]
              └─ reap loop every 5 s
```

## Modules
- `BerthCore` — shared by CLI, daemon, future GUI: `Model` (Slot, Lease, Owner, StateSnapshot), `Protocol` (Request/Event enums, `Wire` JSON lines, `NewlineFrameDecoder`), `Client` (session, auto-spawn), `Config`, `Paths`, `Shell` (async Process runner), `Spawn` (posix_spawn detached), `ProcessInspector` (sysctl owner/liveness).
- `BerthDaemon` — `Broker`, `Server`, `Daemon` (lock, config, reap loop), `DeviceBackend` protocol, `AndroidBackend`, `StateStore`.
- `berth` — ArgumentParser commands + TUI → [[cli]].

## Key decisions
- **Daemon auto-spawn**: no socket → client `posix_spawn`s `berth daemon run` w/ SETSID (outlives client, immune to terminal SIGHUP/SIGINT), retries connect 5 s. `flock` on `daemon.lock` → single daemon; loser exits 0.
- **Connection = claim lifetime**: claim open while queued; disconnect → waiter dropped. Grant needs `ack` before disconnect, else lease back to pool. → no leak if client killed mid-wait (Claude Bash 2 min timeout).
- **Persistence**: `state.json` rewritten each change; restart adopts slots w/ serial still in `adb devices` (free/leased kept, transitional stopped).
- **Paths**: `BERTH_HOME` relocates config/state/socket/logs (default `~/Library/Application Support/berth`, logs `~/Library/Logs/berth`). Socket path ≤ 104 bytes.
- **Shell output → temp files, not pipes**: adb may fork server inheriting pipe → read never EOF.
- Emulators spawned w/ `POSIX_SPAWN_CLOEXEC_DEFAULT` → no inherited daemon socket fds.

## Extending
- iOS: implement `DeviceBackend` via `xcrun simctl` (clone/boot/erase). Broker platform-agnostic.
- GUI: SwiftUI `MenuBarExtra` app reusing `BerthCore` client + `watch` stream.