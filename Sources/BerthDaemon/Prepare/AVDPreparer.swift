import BerthCore
import Foundation

struct AVDPreparer: AVDPreparing {
    private let backend: AndroidBackend
    private let config: Config

    init(backend: AndroidBackend, config: Config) {
        self.backend = backend
        self.config = config
    }

    func knownAVDs() async -> [String] {
        await AVDCatalog.list(sdkRoot: config.resolvedSDKRoot)
    }

    func liveSerials() async -> Set<String> {
        await backend.liveSerials() ?? []
    }

    func avdName(serial: String) async -> String? {
        await backend.avdName(serial: serial)
    }

    func prepare(avd: String, serial: String, settle: Int, progress: @Sendable (String) -> Void) async throws {
        guard let port = AndroidBackend.port(of: serial) else { throw BackendError.command("prepare", "bad serial \(serial)") }
        try Paths.ensureDirectories()
        let log: URL = Paths.logs.appending(path: "prepare-\(avd).log")
        progress("cold booting \(avd) as \(serial) (log: \(log.path))")
        let pid: Int32 = try Spawn.detached(
            backend.emulator,
            ["-avd", avd, "-port", String(port), "-no-window", "-no-boot-anim", "-no-audio", "-no-snapshot-load", "-no-snapshot-save"],
            log: log
        )
        do {
            try await backend.waitReady(serial: serial, pid: pid, timeout: .seconds(config.bootTimeoutSeconds))
            for setting in ["window_animation_scale", "transition_animation_scale", "animator_duration_scale"] {
                _ = try await adb(serial, ["shell", "settings", "put", "global", setting, "0"])
            }
            _ = try await adb(serial, ["shell", "input", "keyevent", "KEYCODE_WAKEUP"])
            _ = try await adb(serial, ["shell", "wm", "dismiss-keyguard"])
            progress("booted, settling \(settle)s")
            try await Task.sleep(for: .seconds(settle))
            let result: ShellResult = try await adb(serial, ["emu", "avd", "snapshot", "save", config.snapshotName], timeout: .seconds(180))
            guard result.stdout.contains("OK"), !result.stdout.contains("KO") else {
                throw BackendError.command("snapshot save", result.stdout + result.stderr)
            }
        } catch {
            await shutdown(serial: serial, pid: pid)
            throw error
        }
        await shutdown(serial: serial, pid: pid)
    }

    private func shutdown(serial: String, pid: Int32) async {
        let backend: AndroidBackend = backend
        await Task.detached { await backend.shutdown(serial: serial, pid: pid) }.value
    }

    private func adb(_ serial: String, _ arguments: [String], timeout: Duration = .seconds(30)) async throws -> ShellResult {
        try await Shell.run(backend.adb, ["-s", serial] + arguments, timeout: timeout)
    }
}
