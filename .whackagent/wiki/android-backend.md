# Android backend

`AndroidBackend: DeviceBackend` (BerthDaemon/AndroidBackend.swift). Stateless; SDK from config `sdkRoot` → `$ANDROID_HOME` → `$ANDROID_SDK_ROOT` → `~/Library/Android/sdk`.

## Boot
`emulator -avd X -port P -read-only -no-window -no-boot-anim -no-audio -snapshot berth-clean -no-snapshot-save`
- Windowed launch (panel, #19): same args minus `-no-window` (`launchArguments(model:port:windowed:snapshot:)`, pure). Reset of windowed slot (agent release) relaunches windowed; manual release never resets.
- Port: first even 5554–5680 not in daemon slots ∪ `adb devices`. Serial = `emulator-P`.
- `-read-only` → same AVD runs N times; writes discarded on exit.
- No `berth-clean` snapshot → `-no-snapshot` cold boot (slow, still clean).
- Ready = `adb shell getprop sys.boot_completed == 1`, poll 2 s, timeout `bootTimeoutSeconds`. Snapshot boot ≈ 2–4 s measured.
- Launcher execs qemu (`qemu-system-aarch64-headless`) in same pid → pid = daemon child; `isProcessAlive` tries `waitpid(WNOHANG)` first (zombie), else `kill(0)`.
- Logs: `<logs>/emulator-P.log`.

## Reset = restart
**Gotcha**: `adb emu avd snapshot load` refused under `-read-only` ("Snapshot load is disabled because -read-only was specified"). Reset = `shutdown` + `launch` + `waitReady`, returns new pid. ≈ 5–6 s release→ready measured.

## Shutdown
`adb -s S emu kill` → wait pid exit 20 s → SIGTERM → 3 s → SIGKILL.

## Prepare (`berth prepare <avd>`, CLI-side)
Refuses if AVD running (daemon slot or `adb emu avd name`). Cold boot non-read-only (`-no-snapshot-load -no-snapshot-save`), animations off, wake + dismiss keyguard, settle N s, `emu avd snapshot save berth-clean`, kill. ≈ 30 s. Snapshot dir `~/.android/avd/<path>/snapshots/berth-clean` (~4 GB).

## AVD dirs
`<avd>.ini` `path=` in `$ANDROID_AVD_HOME` → `$ANDROID_USER_HOME/avd` → `~/.android/avd`. AVD name ≠ dir name (Emu_2 → Pixel_10_Pro_2.avd).