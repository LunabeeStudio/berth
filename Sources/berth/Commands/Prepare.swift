import ArgumentParser
import BerthCore
import BerthDaemon
import Foundation

struct Prepare: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create the clean snapshot an AVD is reset to after each lease (one-time per AVD).",
        discussion: "Cold boots the AVD headless, disables animations, saves the snapshot, shuts down."
    )

    @Argument(help: "AVD name, as listed by `emulator -list-avds`.")
    var avd: String

    @Option(help: "Seconds to let the system settle after boot before saving.")
    var settle: Int = 20

    func run() async throws {
        let config = try await Config.loadOrCreate(discoverModels: AndroidBackend.listAVDs)
        let backend = AndroidBackend(config: config)

        guard await AndroidBackend.listAVDs(sdkRoot: config.resolvedSDKRoot).contains(avd) else {
            throw ValidationError("unknown AVD '\(avd)'")
        }
        if let snapshot = try? await DaemonClient.snapshot(autoSpawn: false), snapshot.slots.contains(where: { $0.model == avd }) {
            throw ValidationError("berth is running instances of \(avd); run `berth stop-all` first")
        }
        let live = await backend.liveSerials() ?? []
        for serial in live where await backend.avdName(serial: serial) == avd {
            throw ValidationError("\(avd) is already running as \(serial); close it first")
        }
        guard let serial = backend.nextSerial(model: avd, taken: live), let port = AndroidBackend.port(of: serial) else {
            throw ValidationError("no free emulator port")
        }

        try Paths.ensureDirectories()
        let log = Paths.logs.appending(path: "prepare-\(avd).log")
        printError("berth: cold booting \(avd) as \(serial) (log: \(log.path))")
        let pid = try Spawn.detached(
            backend.emulator,
            ["-avd", avd, "-port", String(port), "-no-window", "-no-boot-anim", "-no-audio", "-no-snapshot-load", "-no-snapshot-save"],
            log: log
        )
        do {
            try await backend.waitReady(serial: serial, pid: pid, timeout: .seconds(config.bootTimeoutSeconds))
            for setting in ["window_animation_scale", "transition_animation_scale", "animator_duration_scale"] {
                _ = try await adb(backend, serial, ["shell", "settings", "put", "global", setting, "0"])
            }
            _ = try await adb(backend, serial, ["shell", "input", "keyevent", "KEYCODE_WAKEUP"])
            _ = try await adb(backend, serial, ["shell", "wm", "dismiss-keyguard"])
            printError("berth: booted, settling \(settle)s")
            try await Task.sleep(for: .seconds(settle))
            let result = try await adb(backend, serial, ["emu", "avd", "snapshot", "save", config.snapshotName], timeout: .seconds(180))
            guard result.stdout.contains("OK"), !result.stdout.contains("KO") else {
                throw BackendError.command("snapshot save", result.stdout + result.stderr)
            }
        } catch {
            await backend.shutdown(serial: serial, pid: pid)
            printError("berth: \(error)")
            throw ExitCode.failure
        }
        await backend.shutdown(serial: serial, pid: pid)
        printError("berth: saved snapshot '\(config.snapshotName)' for \(avd)")
        if config.entry(for: avd) == nil {
            printError("berth: note: \(avd) is not in the pool; add it to \(Paths.config.path)")
        }
    }

    private func adb(_ backend: AndroidBackend, _ serial: String, _ arguments: [String], timeout: Duration = .seconds(30)) async throws -> ShellResult {
        try await Shell.run(backend.adb, ["-s", serial] + arguments, timeout: timeout)
    }
}
