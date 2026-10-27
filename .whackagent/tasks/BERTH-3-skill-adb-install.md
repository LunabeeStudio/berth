---
issue: BERTH-3
phase: validated
type: improvement
wiki: [[claude-code]]
note:
created: 2026-10-26
---

## Context / Decisions

Ticket: AGP's install tasks (`./gradlew :app:install*`) go through ddmlib, which restarts the adb server when it loses its connection. That kills every agent's emulator connection, and berth's guard only blocks a shell `adb kill-server`. On 2026-10-26 the first of 34 adb server kills matched a Gradle `installDevInternalDebug` run that failed with `[ddms]: '.../adb start-server' failed`. The berth skill should tell agents to install with `adb -s $SERIAL install -r <apk>` after a Gradle assemble, and mention the Android Studio setting *ADB server lifecycle management → Use existing manually managed server* for humans running Studio next to agents.

Decisions (unattended grill, 2026-10-26):
- **Docs change in `docs/AGENTS.md`**, copied byte for byte into the body of `claude-plugin/skills/berth/SKILL.md` (`PluginSyncTests` checks they match). In the *Android emulators* section:
  - The "several steps" example builds with `./gradlew assembleDebug` and installs with `adb -s "$SERIAL" install -r <path to the apk>`.
  - One bullet: install apps with `adb -s "$SERIAL" install -r`, never with Gradle `install…` tasks, because they go through ddmlib, which can restart the shared adb server and drop every agent's emulator.
  - One bullet for agents to relay to the user: when Android Studio runs next to agents, set *Settings → … → ADB server lifecycle management → Use existing manually managed server*. The implementer checks the exact settings path in current Android Studio docs before writing it; unknown path → only the setting name. (autopilot assumption)
- **README**: the same Android Studio advice, one or two lines, near where it tells users to paste `docs/AGENTS.md`. (autopilot assumption: the setting is for humans, and humans read the README)
- **Guard hint, not guard rule.** `GradleRule` keeps its verdicts: it still denies `install…` and `connected…` tasks without `ANDROID_SERIAL` and still allows them with it. Only its deny message changes when the denied tasks include an `install…` task: it points at `./gradlew assemble…` + `adb -s "$SERIAL" install -r <apk>` instead of `berth run -- ./gradlew …`. Denying install tasks even with `ANDROID_SERIAL` would break existing flows; the most reversible step is advice. (autopilot assumption)
- `connected…` tasks also use ddmlib, but they have no adb replacement: unchanged, out of scope.
- **No version bump**: the release flow bumps plugin, marketplace and CLI versions together.
- Wiki: [[claude-code]], *Rules* section, `GradleRule` line notes the install hint.

## Acceptance criteria

- `docs/AGENTS.md` tells agents to install apps with `adb -s "$SERIAL" install -r <apk>` after a Gradle assemble, never with Gradle `install…` tasks, and says why (ddmlib can restart the shared adb server and drop every agent's emulator).
- The "several steps" example in `docs/AGENTS.md` uses `./gradlew assembleDebug` then `adb -s "$SERIAL" install -r …`.
- `docs/AGENTS.md` names the Android Studio setting "Use existing manually managed server" (ADB server lifecycle management) for the user to set when Studio runs next to agents.
- The body of `claude-plugin/skills/berth/SKILL.md` is identical to `docs/AGENTS.md` (`PluginSyncTests` passes).
- The README mentions the same Android Studio setting for humans.
- `berth guard` on `./gradlew installDebug` without `ANDROID_SERIAL` still denies, and its message suggests `assemble` + `adb -s "$SERIAL" install -r`. `./gradlew connectedDebugAndroidTest` without `ANDROID_SERIAL` still denies with the `berth run` hint. Both are allowed with `ANDROID_SERIAL` set, as before.
- `swift test` passes, with a guard test for the new install hint.

## Implementation

One brick (autopilot, 2026-10-26).
- `docs/AGENTS.md`: the "several steps" example runs `./gradlew assembleDebug`, then `adb -s "$SERIAL" install -r app/build/outputs/apk/debug/app-debug.apk`. A new bullet says to install with `adb -s "$SERIAL" install -r` and never with Gradle `install…` tasks, because ddmlib can restart the shared adb server. Another bullet starts "Tell the user:" and names ADB server lifecycle management → "Use existing manually managed server". Only the setting name is written, because the settings path could not be confirmed.
- `claude-plugin/skills/berth/SKILL.md`: the body is regenerated from `docs/AGENTS.md`. The frontmatter is untouched.
- `README.md`: one paragraph with the Android Studio advice, after the line about pasting `docs/AGENTS.md`.
- `Sources/berth/Guard/Rules/GradleRule.swift`: the leaf task names are parsed once (`leafNames`). An `install…` task (not `installDist`) gets the install hint, which also wins when the command mixes install and connected tasks. Connected-only commands keep the `berth run` hint. Verdicts are unchanged.
- `Tests/berthTests/Guard/DeviceCommandGuardTests.swift`: tests for the install hint (3 commands), the connected hint, and `./gradlew installDebug` allowed when `ANDROID_SERIAL` is set.
- Wiki [[claude-code]]: the `GradleRule` line notes both hints.
- No version bump.

## Review

### validation (autopilot) — 2026-10-26
LENSES: style ✓ · elegance ✓ · structure ✓ · correctness ✓
- Round 1, 6 minor findings:
  - [correctness] The install message gave no claim step (`$SERIAL` is unset when the rule fires).
  - [correctness] No test that install is allowed when `ANDROID_SERIAL` is set.
  - [style] The tests compared optionals instead of unwrapping them with `#require`.
  - [style] A needless `ANDROID_SERIAL` prefix on `assembleDebug`.
  - [correctness] The Android Studio bullet did not tell the agent to relay it to the user.
  - [correctness] The wiki line was not updated.
- Autofix: all five code findings are fixed. The orchestrator wrote the wiki line.
- Round 2: clean.

## Verification

- ✅ `swift build` and the full `swift test` are green. `PluginSyncTests` confirms the SKILL.md body equals AGENTS.md.
- ✅ `berth guard` with `./gradlew :app:installDebug` exits 2 with `berth: Gradle install tasks can restart the shared adb server and hit every connected device. Run ./gradlew assemble…, then SERIAL=$(berth claim) and adb -s "$SERIAL" install -r <apk>.`
- ✅ `berth guard` with `./gradlew connectedDebugAndroidTest` exits 2 with `berth: Gradle connected tasks hit every connected device. Run berth run -- ./gradlew …`
- ✅ `berth guard` with `ANDROID_SERIAL=emulator-5554 ./gradlew installDebug` exits 0 with no output.

## Feedback
