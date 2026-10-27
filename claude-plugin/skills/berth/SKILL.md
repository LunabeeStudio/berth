---
name: berth
description: Use whenever a task needs an Android emulator or iOS simulator - running adb, emulator, Gradle connected or instrumented tests or install tasks, xcrun simctl, xcodebuild test, UI tests, or screenshots on a device, or a human must act on it (login, sign-in, 2FA, captcha, showing the emulator or simulator window). Explains how to claim and release devices with berth so parallel agents do not collide.
---

## Android emulators (berth)

Emulators are shared with other agents running in parallel. Never use an emulator you did not claim,
never start or kill emulators yourself, and never run `adb` without a target serial.

Preferred — claim, run, release in one command (the emulator is released even if the command fails):

```bash
berth run --label "<short task name>" --timeout 110 -- ./gradlew connectedDebugAndroidTest
```

`ANDROID_SERIAL` is set for the command, so `adb`, Gradle and the `android` CLI target the claimed emulator.

For several steps on the same emulator:

```bash
SERIAL=$(berth claim --label "<short task name>" --timeout 110)   # exit 2 = none free yet, retry
./gradlew assembleDebug
adb -s "$SERIAL" install -r app/build/outputs/apk/debug/app-debug.apk
ANDROID_SERIAL="$SERIAL" ./gradlew connectedDebugAndroidTest
berth release "$SERIAL"                                          # always release when done
```

- Shell commands time out after ~2 min: keep `--timeout 110` and retry on exit code 2, or run the claim in the background.
- Install with `adb -s "$SERIAL" install -r`, never with Gradle `install…` tasks: ddmlib can restart the shared adb server and drop every agent's emulator.
- A released emulator is wiped back to a clean snapshot; nothing you install survives.
- Leases expire after 1 h (`berth renew "$SERIAL"` to extend) and are reclaimed when your session ends.
- `berth status` shows who holds what and the waiting queue.
- Tell the user: if Android Studio runs next to agents, set ADB server lifecycle management → "Use existing manually managed server" so it never restarts the shared adb server.

## iOS simulators (berth)

Simulators are shared with other agents running in parallel. Never boot, erase or shut down a simulator yourself; use only the one berth leases you.

Preferred:

```bash
berth run --ios --label "<short task name>" --timeout 110 -- sh -c 'xcodebuild -scheme App -destination "id=$SIMULATOR_UDID" test'
```

For several steps on the same simulator:

```bash
UDID=$(berth claim --ios --label "<short task name>" --timeout 110)   # exit 2 = none free, retry
xcrun simctl install "$UDID" App.app
xcrun simctl launch "$UDID" com.example.app
berth release "$UDID"                                                # always release
```

- A released simulator is erased; nothing you install survives.
- `berth claim` without `--ios` still returns an Android emulator.

## When a human must act on the device

Login, sign-in, 2FA, captcha, or anything you cannot automate: ask the user to do it on the device.

```bash
SERIAL=$(berth claim --label "<short task name>" --timeout 110)   # not `berth run`: it releases the device when its command ends
berth mirror "$SERIAL"                                           # opens a window on the user's screen; use the UDID for a simulator
```

- Tell the user exactly what to do in that window, then wait for their reply in chat before you continue.
- Do not release the device meanwhile; `berth renew "$SERIAL"` if the wait is long.
- Works for Android (needs scrcpy) and iOS (needs Xcode 27).
- Never run `scrcpy` yourself: the guard blocks it.
