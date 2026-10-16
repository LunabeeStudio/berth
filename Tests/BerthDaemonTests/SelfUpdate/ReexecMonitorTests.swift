import Foundation
import Synchronization
import Testing

@testable import BerthDaemon

@Suite
struct ReexecMonitorTests {
    @Test
    func `settled change while idle execs once`() async throws {
        var f: Fixture = try .init()
        defer { f.cleanUp() }
        try f.replaceFile("bb")

        await f.monitor.poll()
        #expect(f.probe.execs == 0)
        await f.monitor.poll()

        #expect(f.probe.execs == 1)
        #expect(f.probe.logs == ["re-exec after binary change"])
    }

    @Test
    func `failed verification logs once and never execs`() async throws {
        var f: Fixture = try .init()
        defer { f.cleanUp() }
        f.probe.setLoadable(false)
        try f.replaceFile("bb")

        for _ in 0..<4 { await f.monitor.poll() }

        #expect(f.probe.execs == 0)
        #expect(f.probe.logs == ["new executable fails verification, not restarting into it"])
    }

    @Test
    func `failed exec is not retried until the file changes again`() async throws {
        var f: Fixture = try .init()
        defer { f.cleanUp() }
        try f.replaceFile("bb")
        for _ in 0..<4 { await f.monitor.poll() }
        #expect(f.probe.execs == 1)

        try f.replaceFile("ccc")
        for _ in 0..<3 { await f.monitor.poll() }

        #expect(f.probe.execs == 2)
    }

    @Test
    func `busy broker delays the exec until a later idle poll`() async throws {
        var f: Fixture = try .init()
        defer { f.cleanUp() }
        f.probe.setIdle(false)
        try f.replaceFile("bb")

        for _ in 0..<3 { await f.monitor.poll() }
        #expect(f.probe.execs == 0)
        f.probe.setIdle(true)
        await f.monitor.poll()

        #expect(f.probe.execs == 1)
    }
}

private extension ReexecMonitorTests {
    final class Probe: Sendable {
        private let state: Mutex<ProbeState> = .init(.init())

        var execs: Int { state.withLock { $0.execs } }
        var logs: [String] { state.withLock { $0.logs } }
        var loadable: Bool { state.withLock { $0.loadable } }

        func setIdle(_ idle: Bool) { state.withLock { $0.idle = idle } }
        func setLoadable(_ loadable: Bool) { state.withLock { $0.loadable = loadable } }

        func gate(_ body: @Sendable () -> Void) -> Bool {
            guard state.withLock({ $0.idle }) else { return false }
            body()
            return true
        }

        func recordExec() { state.withLock { $0.execs += 1 } }
        func record(_ line: String) { state.withLock { $0.logs.append(line) } }
    }

    struct ProbeState {
        var idle: Bool = false
        var loadable: Bool = false
        var execs: Int = 0
        var logs: [String] = []
    }

    struct Fixture {
        let url: URL
        let probe: Probe = .init()
        var monitor: ReexecMonitor

        init() throws {
            url = FileManager.default.temporaryDirectory.appending(path: "berth-monitor-\(UUID().uuidString)")
            try Data("a".utf8).write(to: url)
            let probe: Probe = probe
            monitor = .init(
                watch: .init(path: url.path),
                verify: { probe.loadable },
                performIfIdle: { probe.gate($0) },
                exec: { probe.recordExec() },
                log: { probe.record($0) }
            )
            probe.setIdle(true)
            probe.setLoadable(true)
        }

        func replaceFile(_ content: String) throws {
            let replacement: URL = url.deletingLastPathComponent().appending(path: "berth-monitor-\(UUID().uuidString)")
            try Data(content.utf8).write(to: replacement)
            rename(replacement.path, url.path)
        }

        func cleanUp() { try? FileManager.default.removeItem(at: url) }
    }
}
