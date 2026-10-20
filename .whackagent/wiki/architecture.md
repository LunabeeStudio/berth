# Architecture

One binary `berth`, two roles: short-lived **client** commands + long-lived **daemon**.

```
agent shell → berth claim/run/release/status/top (client, BerthCore.DaemonClient)
berth-bar (menu bar, BerthCore.DaemonWatch + windowed claim/release, never autospawn; scrcpy mirror children)
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
- `BerthCore` — shared by CLI, daemon, bar: `Model` (Slot, Lease, Owner, StateSnapshot), `Platform` (android | ios), `Protocol` (Request/Event enums, `Wire` JSON lines, `NewlineFrameDecoder`), `Client` (session, auto-spawn), `Config` (pool entry `avd` | `simulator`, `adbPath` / `defaultADBPath()` (SDK adb, one home for CLI + bar), `platform(of:)`, `models(for:)`, `load(from:)` (nil = missing/unreadable), `save(to:)` (pretty, sorted, atomic; `loadOrCreate` uses it), `setAutoUpdate(_:at:)` (raw JSON edit of that key only, file must decode)), `Extensions/` (`[PoolEntry].entry(for:)` / `platform(of:)`, shared by `Config` + bar), `Paths`, `Shell` (async Process runner), `Spawn` (posix_spawn detached, optional env), `ProcessInspector` (sysctl owner/liveness), `Watch` (`DaemonWatch` reconnecting watch stream), `Format` (`DurationFormat`), `Launchd` (`LaunchAgent`: per-user plist in `~/Library/LaunchAgents`, write/remove/isInstalled, no launchctl), `Version` (`BerthVersion.current`, stamped at release → [[release]]), `Update` (self-updater → [[update]]), `Mirror/` shared by CLI + bar: `Scrcpy/` (`ScrcpyLocator`, `ScrcpyArguments`, `MirrorMode`, `ScrcpyMirror` = log URL `mirror-<serial>.log` + not-found text), `DeviceHub/` (`DeviceHubURL`, `SimulatorMirrorOpener` protocol, `SystemSimulatorMirrorOpener` = `NSWorkspace`, only AppKit import in BerthCore).
- `BerthBar` — `berth-bar` AppKit `NSStatusItem` + `NSPopover` (SwiftUI panel) app, BerthCore only. `App/` entry, `Status/` model + state, `MenuBar/` status item + label, `Panel/` views, `Login/` launch-at-login checkbox (`com.berth.bar` plist), `Update/` `AutoUpdateSetting` (auto update checkbox → `autoUpdate` in `config.json`, → [[update]]), `Launch/` `EmulatorLauncher` (windowed claim + ack, release, error line; `DaemonActions` protocol injected, `DaemonClientActions` default), `Mirror/` `MirrorController` (routes by platform: Android → scrcpy per serial, iOS → DeviceHub; caption) + `MirrorEligibility` (rows + tooltip `help(for:pool:)`); `Mirror/Scrcpy/` (`MirrorLauncher` protocol injected, `SystemMirrorLauncher` default = Foundation `Process` child); locator, arguments, DeviceHub URL + opener from `BerthCore/Mirror`. Watches daemon + sends windowed claims / release; `autoSpawn: false` (spawn would relaunch itself).
- `BerthDaemon` — `Broker`, `Server`, `Daemon` (lock, config, reap loop), `Backends/` (`DeviceBackend` protocol, `DeviceRouter`, `AndroidBackend`, `IOSSimulatorBackend`), `StateStore`, `SelfUpdate/` (auto update + same-pid re-exec → [[update]]).
- `berth` — ArgumentParser commands + TUI → [[cli]]; `Mirror/` (`MirrorResolver` snapshot + serial → target or error, `MirrorFlow`, `SpawnMirrorLauncher` = detached scrcpy) for `berth mirror`; `Guard/` shell tokenizer + device rules for `berth guard` → [[claude-code]].
- `tools/desktop/desk.swift` — standalone script (outside package, `xcrun swift`): `desk-state`, `window-id <pid>`, `capture <pid>` (`screencapture -l`). Desktop proofs of `berth-bar` never take mouse/keyboard/focus → `CLAUDE.md#Desktop proofs`. Panel proven offscreen: `BerthBarTests/Panel` renders `StatusPanel` per state (`StatusModel.init(state:now:)`), `BERTH_PANEL_PNG_DIR` → PNGs. macOS 27: status item drawn by `MenuBarAgent`, not app pid → not capturable; popover open steals focus (`NSApp.activate`) → human checks click + Quit.

## Key decisions
- **Daemon auto-spawn**: no socket → client `posix_spawn`s `berth daemon run` w/ SETSID (outlives client, immune to terminal SIGHUP/SIGINT), retries connect 5 s. `flock` on `daemon.lock` → single daemon; loser exits 0.
- **Connection = claim lifetime**: claim open while queued; disconnect → waiter dropped. Grant needs `ack` before disconnect, else lease back to pool. → no leak if client killed mid-wait (Claude Bash 2 min timeout).
- **Persistence**: `state.json` rewritten each change; restart adopts slots w/ serial still in `adb devices` (free/leased kept, transitional stopped).
- **Paths**: `BERTH_HOME` relocates config/state/socket/logs (default `~/Library/Application Support/berth`, logs `~/Library/Logs/berth`). Socket path ≤ 104 bytes.
- **Shell output → temp files, not pipes**: adb may fork server inheriting pipe → read never EOF.
- **Login items = launchd agents, not `SMAppService`**: `berth-bar` bare executable, no `.app` bundle. Daemon `com.berth.daemon` (`berth daemon install`, KeepAlive, bootstrap now). Bar `com.berth.bar` (panel checkbox, RunAtLoad only, no KeepAlive → Quit sticks; no bootstrap/bootout → no 2nd instance, no self-kill). Checkbox on ⇔ plist exists. Plist keeps binary path + `BERTH_HOME` from when enabled. → #8
- **Windowed = human's emulator**: panel "Launch emulator" → claim `windowed: true` (Android pool AVD, label `you`, owner berth-bar) → windowed boot (or reuse free windowed), manual lease forever; release → free pool slot, no reset, any claim takes it as is. One claim loop `DaemonClient.claim` shared by CLI `ClaimFlow` + bar. → [[broker]], #19
- **Mirror = scrcpy child of berth-bar, daemon untouched**: Mirror button on headless Android rows `free`/`leased` → scrcpy (`PATH`, then `/opt/homebrew/bin`, `/usr/local/bin`: launchd PATH minimal), env `ADB` = SDK adb (same adb server as berth), `--no-audio`, title `<serial> <model>`. Free → control; leased → `--no-control` + ` (view only)`. Mirrored free slot gets leased → stop + reopen view-only (scrcpy can't drop control live). One process per serial (2nd click → `activate`). Exit 0/2 (closed, device gone on reset) silent; other exit → caption `mirror <serial> failed, see <logs>/mirror-<serial>.log`. Quit → `applicationWillTerminate` stops own children only. Foundation `Process`, not `Spawn.detached`: bar owns it, sees exit. → #22
- **iOS mirror = DeviceHub, not a child**: Mirror button also on iOS rows `free`/`leased` → `NSWorkspace` opens `devices://device/open?id=<udid>` (Xcode 27 DeviceHub, `com.apple.dt.Devices`; undocumented URL, proven by hand: compact window, attaches to `simctl`-booted sim w/o reboot). No view-only mode → input reaches leased sim; tooltip warns. Bar keeps no session: no free → leased switch, no stop on Quit. No `devices` handler → caption `DeviceHub not found: needs Xcode 27`. No Simulator.app fallback (Xcode ≤ 26). → [[ios-backend]], #29
- **Agent mirror = `berth mirror`, CLI-only**: agent needing human action (login, 2FA, captcha) opens same window from its shell. CLI reads snapshot (`autoSpawn: false`), slot must be `leased` (no owner check, like release/renew), then Android → `Spawn.detached` scrcpy with control + `ADB` env, iOS → DeviceHub URL. Returns at once (shell timeout ~2 min, DeviceHub gives no exit): agent asks user in chat. No pid kept: release restarts emulator → scrcpy exits itself. Bar unaware → 2nd window possible (accepted). No daemon / protocol change. → [[cli]], [[claude-code]], #30
- Emulators spawned w/ `POSIX_SPAWN_CLOEXEC_DEFAULT` → no inherited daemon socket fds.

## Extending
- Platforms: one pool, queue, `maxRunning` for Android + iOS (eviction across platforms OK, same RAM). Broker knows platform only to filter claims. → [[ios-backend]]
- GUI: done → `BerthBar`.
