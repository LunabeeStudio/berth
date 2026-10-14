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
adb -s "$SERIAL" install app.apk
ANDROID_SERIAL="$SERIAL" ./gradlew connectedDebugAndroidTest
berth release "$SERIAL"                                          # always release when done
```

- Shell commands time out after ~2 min: keep `--timeout 110` and retry on exit code 2, or run the claim in the background.
- A released emulator is wiped back to a clean snapshot; nothing you install survives.
- Leases expire after 1 h (`berth renew "$SERIAL"` to extend) and are reclaimed when your session ends.
- `berth status` shows who holds what and the waiting queue.

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
