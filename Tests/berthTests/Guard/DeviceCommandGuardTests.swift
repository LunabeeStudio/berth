import Testing

@testable import berth

@Suite
struct DeviceCommandGuardTests {
    private static let denied: [String] = [
        "adb install app.apk",
        "adb shell pm list packages",
        "adb -e shell ls",
        "adb kill-server",
        "adb -s emulator-5554 emu kill",
        "emulator -avd Pixel_9",
        "$ANDROID_HOME/emulator/emulator @Pixel_9",
        "xcrun simctl boot ABC",
        "xcrun simctl shutdown all",
        "xcrun simctl install booted App.app",
        "./gradlew connectedDebugAndroidTest",
        "./gradlew :app:installDebug",
        "xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 17'",
        "pkill -f qemu",
        "git status && adb logcat",
        "sh -c 'adb install app.apk'",
        "sudo adb install app.apk",
        "FOO=1 adb install app.apk",
        "bash -c \"echo hi; adb shell ls\"",
        "killall Simulator",
        "for f in *.apk; do adb install \"$f\"; done",
        "if true; then adb install x; fi",
        "ls *.apk | xargs adb install",
        "ls *.apk | xargs -n 1 adb install",
        "sudo -u me adb install x",
        "nice -n 10 ./gradlew connectedCheck",
        "env -u FOO adb install x",
        "timeout -s KILL 5 adb install x",
        "bash -lc 'adb install app.apk'",
        "xcrun xcodebuild test -destination \"platform=iOS Simulator,name=iPhone 17\"",
        "xcrun --sdk iphonesimulator simctl boot ABC",
        "xcrun simctl openurl booted https://example.com",
        "while true; do adb shell ls; done",
        "cat > run.sh <<'EOF'\nx\nEOF\nadb install app.apk",
        "adb install a.apk # trailing comment",
        "echo $((1<<2)); adb install x",
        "sh <<EOF\nadb install x\nEOF",
        "cat <<EOF | sh\nadb install x\nEOF",
        "bash <<'EOF'\necho hi\nadb shell ls\nEOF",
        "time -p ./gradlew connectedCheck",
        "| adb install x",
    ]

    private static let allowed: [String] = [
        "berth run -- ./gradlew connectedDebugAndroidTest",
        "berth run -- sh -c 'adb install app.apk'",
        "adb -s \"$SERIAL\" install app.apk",
        "ANDROID_SERIAL=$S ./gradlew connectedDebugAndroidTest",
        "export ANDROID_SERIAL=$(berth claim); adb install app.apk",
        "adb devices",
        "adb version",
        "adb start-server",
        "adb --version",
        "adb -d logcat",
        "emulator -list-avds",
        "emulator -help-all",
        "xcrun simctl list devices",
        "xcrun simctl install \"$UDID\" App.app",
        "xcodebuild test -destination \"id=$SIMULATOR_UDID\"",
        "xcodebuild test -destination 'platform=iOS Simulator,id=ABC'",
        "./gradlew assembleDebug",
        "grep -r adb README.md",
        "echo \"adb install app.apk\"",
        "pkill -f node",
        "sh -c 'unbalanced",
        "adb install \"app.apk",
        "cat > run.sh <<'EOF'\nadb install app.apk\nEOF",
        "cat <<-EOF\n\tadb install x\n\tEOF",
        "cat <<EOF | sh\nbody\nEOF",
        "ls # ; adb install x",
        "xcrun simctl list devices booted",
        "command -v emulator",
        "command -V adb",
        "./gradlew test --tests installerTest",
        "./gradlew installDist",
        "./gradlew assemble -x installDebug",
        "for f in *.apk; do echo \"$f\"; done",
        "cat <<< \"adb install x\"",
        "echo $((1<<2))",
        "| sh",
        "(| sh)",
        "cat > run.sh <<EOF\nadb install x\nEOF",
    ]

    @Test(arguments: denied)
    func `denies device command outside a lease`(command: String) {
        let verdict: GuardVerdict = DeviceCommandGuard(environment: [:]).verdict(for: command)
        guard case let .deny(reason) = verdict else {
            Issue.record("expected deny for \(command)")
            return
        }
        #expect(reason.hasPrefix("berth: "))
        #expect(!reason.contains("\n"))
    }

    @Test(arguments: allowed)
    func `allows leased or harmless command`(command: String) {
        #expect(DeviceCommandGuard(environment: [:]).verdict(for: command) == .allow)
    }

    @Test
    func `ANDROID_SERIAL in the hook environment allows adb`() {
        let guardrail: DeviceCommandGuard = .init(environment: ["ANDROID_SERIAL": "emulator-5554"])
        #expect(guardrail.verdict(for: "adb install app.apk") == .allow)
        #expect(guardrail.verdict(for: "./gradlew connectedCheck") == .allow)
    }

    @Test
    func `ANDROID_SERIAL does not allow kill-server`() {
        let guardrail: DeviceCommandGuard = .init(environment: ["ANDROID_SERIAL": "emulator-5554"])
        #expect(guardrail.verdict(for: "adb kill-server") != .allow)
    }
}

extension DeviceCommandGuardTests {
    @Test
    func `custom rules replace the defaults`() {
        let guardrail: DeviceCommandGuard = .init(environment: [:], rules: [])
        #expect(guardrail.verdict(for: "adb install x") == .allow)
    }
}
