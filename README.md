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
mkdir -p ~/.local/bin && curl -fsSL https://github.com/LunabeeStudio/berth/releases/latest/download/berth-macos-arm64.tar.gz | tar -xz -C ~/.local/bin
berth prepare <AVD>                         # once per AVD: saves the clean snapshot (≈30 s)
berth status                                # starts the daemon, writes the default config
```

`~/.local/bin` must be on your PATH. The archive holds `berth` and `berth-bar`.

Optional: `berth daemon install` starts the daemon at login via launchd (otherwise any command starts it).

### From source

```bash
swift build -c release
cp .build/release/berth .build/release/berth-bar ~/.local/bin/
```

## Use

| Command | |
|---|---|
| `berth run [--avd X] [--label L] -- <cmd…>` | claim, run `cmd` with `ANDROID_SERIAL` set, release |
| `berth run --ios [--simulator "iPhone 17"] -- <cmd…>` | same for an iOS simulator: `SIMULATOR_UDID` is set instead |
| `berth claim [--avd X] [--timeout 600] [--ttl 3600] [--label L] [--json]` | prints the serial (a UDID with `--ios` / `--simulator "<name>"`); queues if none free; exit 2 on timeout |
| `berth release <serial\|lease>` | give it back (emulator is reset) |
| `berth renew <serial\|lease> [--ttl s]` | extend a lease |
| `berth status [--json]` / `berth top` | one-shot table / live TUI (`↑↓` select, `r` release, `x` stop, `q` quit) |
| `berth guard` | Claude Code hook: blocks device commands outside a lease (reads the hook payload on stdin) |
| `berth stop-all` | stop every emulator berth started |
| `berth update [--check]` | install the latest GitHub release over `berth` (and the `berth-bar` beside it); `--check` only reports the running and latest versions |
| `berth daemon stop` | stop the daemon (emulators keep running and are adopted on restart); needed after editing the config |

Paste [`docs/AGENTS.md`](docs/AGENTS.md) into your agents' `CLAUDE.md` / `AGENTS.md` (Claude Code users: see below).

## Claude Code

With `berth` on your PATH (see Install), add the plugin:

```
/plugin marketplace add LunabeeStudio/berth
/plugin install berth@berth
```

- Skill `berth`: the agent rules, loaded when a task needs a device.
- Guard hook: `berth guard` runs before every Bash call and blocks `adb` without a serial, emulator and `simctl` lifecycle commands, `booted`, `xcodebuild` by simulator name, Gradle connected/install tasks without `ANDROID_SERIAL`, and `pkill` of emulators. It tells Claude which berth command to use instead.

Without `berth` on PATH the hook does nothing. Disable the plugin in `/plugin` to opt out.

## Menu bar

`berth-bar` is a menu bar item showing what is running: label `<leased>/<running>` (plus `+N` when claims wait), panel with emulators and the queue. It can also launch an emulator for you.

```bash
berth-bar &                                 # no Dock icon; Quit is in the panel
```

Installed with `berth` (see Install). From a source checkout: `swift build -c release && .build/release/berth-bar &`.

The panel has a "Launch at login" checkbox. It writes `~/Library/LaunchAgents/com.berth.bar.plist` (label `com.berth.bar`), which keeps the path of the binary: toggle it off and on after moving `berth-bar`.

The "Launch emulator" menu lists the Android AVDs of the pool and shows only while the daemon runs. Choosing one boots a new instance with a visible window, leased to you (label `you`). It is a normal claim: it waits in the queue when the pool is full, counts toward `maxRunning` and `maxInstances`, and no agent is ever given it. The lease never expires and is never reclaimed, even after `berth-bar` quits. Neither `berth stop-all` nor eviction stops it; `berth stop <serial>` does. A refused launch shows its reason under the menu. Android only.

The emulator row shows a "Release" button instead of a remaining time. Release makes berth forget the emulator: it disappears from berth, keeps running as your own, and berth never touches it again. Closing its window stops it and berth notices.

It never starts the daemon: while the daemon is down the panel says so, and it reconnects on its own once the daemon runs.

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
- **iOS simulators**: add `{"simulator": "iPhone 17", "maxInstances": 2}` to the pool (never added automatically).
  At daemon start berth creates the missing `berth-<simulator>-<k>` devices with `xcrun simctl create` and only ever
  boots, erases or shuts down devices named `berth-…`; your own simulators are never touched. Every lease starts from
  `simctl erase` + a headless `simctl boot`, and a release does the same again. The serial is the device UDID:
  `berth run --ios -- sh -c 'xcodebuild -destination "id=$SIMULATOR_UDID" test'`. Simulators share the queue and `maxRunning` with emulators;
  `berth claim` without `--ios` never returns one, and `berth prepare` is Android-only.

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
  "autoUpdate": true,
  "pool": [
    { "avd": "Pixel_9", "maxInstances": 2 },
    { "simulator": "iPhone 17", "maxInstances": 2 }
  ]
}
```

## Updates

`berth update` downloads the latest release from GitHub, checks its SHA-256, and replaces `berth` and the `berth-bar` beside it
(the install directory must be writable). With `autoUpdate` true (the default, also when the key is absent) the daemon does the
same about a minute after it starts and then every 24 h, and logs the outcome in `daemon.log`. After the binary changes on disk the
daemon restarts itself in place once no lease, waiting claim or booting emulator is left; emulators and leases are kept.
Set `"autoUpdate": false` to opt out. Local `dev` builds never update. A running `berth-bar` keeps the old version until you relaunch it.

Logs: `~/Library/Logs/berth/` (`daemon.log`, one file per emulator). `BERTH_HOME` relocates config, state,
socket and logs (keep it short: Unix socket paths are limited to 104 bytes).

## Develop

```bash
swift build && swift test       # broker logic is tested against a fake backend, no emulator needed
```

Layout: `BerthCore` (model, wire protocol, client, process helpers), `BerthDaemon` (broker actor, NIO server,
`DeviceBackend`, `AndroidBackend`, `IOSSimulatorBackend` over `simctl`, `DeviceRouter`), `berth` (CLI + TUI). A SwiftUI menu-bar app can reuse `BerthCore`'s client and `watch` stream.

## License

MIT, see [LICENSE](LICENSE).
