# berth

Lease Android emulators to AI agents running in parallel, so they never collide on a device.
Agents keep using Google's tools (`adb`, Gradle, `android`); berth only decides **which** emulator each one gets.

```
agent ─► berth claim / run / release ─► daemon (auto-started, Unix socket)
                                          ├─ FIFO queue of waiting claims
                                          ├─ boots AVDs on demand (-read-only, headless)
                                          └─ resets on release, reclaims abandoned leases, stops idle emulators
```

Native Swift 6 binary for macOS (Apple silicon), no runtime.

## Install

```bash
swift build -c release
cp .build/release/berth ~/.local/bin/      # or anywhere on PATH
berth prepare <AVD>                         # once per AVD: saves the clean snapshot (≈30 s)
berth status                                # starts the daemon, writes the default config
```

Optional: `berth daemon install` starts the daemon at login via launchd (otherwise any command starts it).

## Use

| Command | |
|---|---|
| `berth run [--avd X] [--label L] -- <cmd…>` | claim, run `cmd` with `ANDROID_SERIAL` set, release |
| `berth claim [--avd X] [--timeout 600] [--ttl 3600] [--label L] [--json]` | prints the serial; queues if none free; exit 2 on timeout |
| `berth release <serial\|lease>` | give it back (emulator is reset) |
| `berth renew <serial\|lease> [--ttl s]` | extend a lease |
| `berth status [--json]` / `berth top` | one-shot table / live TUI (`↑↓` select, `r` release, `x` stop, `q` quit) |
| `berth stop-all` | stop every emulator berth started |
| `berth daemon stop` | stop the daemon (emulators keep running and are adopted on restart); needed after editing the config |

Paste [`docs/AGENTS.md`](docs/AGENTS.md) into your agents' `CLAUDE.md` / `AGENTS.md`.

## How it behaves

- **Boot**: `emulator -avd X -read-only -no-window -snapshot berth-clean -no-snapshot-save` on the next free even port;
  `-read-only` lets one AVD run several times. From the prepared snapshot an emulator is ready in a few seconds;
  without one it cold boots.
- **Reset on release**: restart from the clean snapshot (the emulator refuses `snapshot load` under `-read-only`,
  and a read-only instance drops every write on exit). Takes ~5 s.
- **Queue**: strict FIFO, except a waiter for a busy AVD never blocks a waiter that can use a free one.
  When the global limit is reached, an idle emulator of another AVD is stopped to make room.
- **Abandoned leases**: the owner is the nearest non-shell ancestor of `berth claim` (for Claude Code: the `claude`
  process). The lease is reclaimed when that process exits, when the TTL expires, or when the claiming client
  disconnects before receiving its grant. A waiting claim leaves the queue when its client disconnects.
- Emulators berth did not start are never handed out or touched.

## Config

`~/Library/Application Support/berth/config.json`, created on first run with every AVD in the pool:

```json
{
  "sdkRoot": "/Users/me/Library/Android/sdk",
  "maxRunning": 4,
  "idleShutdownSeconds": 900,
  "defaultTTLSeconds": 3600,
  "bootTimeoutSeconds": 300,
  "snapshotName": "berth-clean",
  "pool": [{ "avd": "Pixel_9", "maxInstances": 2 }]
}
```

Logs: `~/Library/Logs/berth/` (`daemon.log`, one file per emulator). `BERTH_HOME` relocates config, state,
socket and logs (keep it short: Unix socket paths are limited to 104 bytes).

## Develop

```bash
swift build && swift test       # broker logic is tested against a fake backend, no emulator needed
```

Layout: `BerthCore` (model, wire protocol, client, process helpers), `BerthDaemon` (broker actor, NIO server,
`DeviceBackend` + `AndroidBackend`), `berth` (CLI + TUI). An iOS simulator backend would implement `DeviceBackend`
(`simctl clone/boot/erase`); a SwiftUI menu-bar app can reuse `BerthCore`'s client and `watch` stream.

## License

MIT, see [LICENSE](LICENSE).
