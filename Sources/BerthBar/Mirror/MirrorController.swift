import AppKit
import BerthCore
import Foundation
import Observation

@Observable
@MainActor
final class MirrorController {
    private static let windowClosed: Int32 = 0
    private static let deviceDisconnected: Int32 = 2
    private static let normalExitCodes: Set<Int32> = [windowClosed, deviceDisconnected]

    private(set) var caption: String?

    @ObservationIgnored private var sessions: [String: Session] = [:]
    private let launcher: any MirrorLauncher
    private let locator: ScrcpyLocator
    private let logs: URL
    private let activate: @MainActor (Int32) -> Void

    init(
        launcher: any MirrorLauncher = SystemMirrorLauncher(),
        locator: ScrcpyLocator = .init(),
        logs: URL = Paths.logs,
        activate: @escaping @MainActor (Int32) -> Void = { NSRunningApplication(processIdentifier: $0)?.activate() }
    ) {
        self.launcher = launcher
        self.locator = locator
        self.logs = logs
        self.activate = activate
    }

    private static func launchFailedCaption(serial: String, error: any Error) -> String {
        "mirror \(serial) failed: \(error.localizedDescription)"
    }

    private static func exitFailedCaption(serial: String, log: URL) -> String {
        "mirror \(serial) failed, see \(log.path)"
    }

    func open(_ slot: Slot) {
        caption = nil
        if let session = sessions[slot.serial] {
            activate(session.process.pid)
            return
        }
        start(serial: slot.serial, model: slot.model, mode: slot.state == .free ? .control : .viewOnly)
    }

    func apply(_ snapshot: StateSnapshot) {
        for slot in snapshot.slots where slot.state == .leased {
            guard let session = sessions[slot.serial], session.mode == .control else { continue }
            stop(serial: slot.serial)
            start(serial: slot.serial, model: session.model, mode: .viewOnly)
        }
    }

    func stopAll() {
        sessions.keys.forEach(stop(serial:))
    }

    func observe(_ model: StatusModel) {
        let state: StatusState = withObservationTracking {
            model.state
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe(model) }
        }
        if case let .live(snapshot) = state {
            apply(snapshot)
        }
    }

    private func start(serial: String, model: String, mode: MirrorMode) {
        guard let executable = locator.locate() else {
            caption = "scrcpy not found: brew install scrcpy"
            return
        }
        let log: URL = logs.appending(path: "mirror-\(serial).log")
        let id: UUID = .init()
        do {
            let process: any MirrorProcess = try launcher.launch(
                executable: executable,
                arguments: ScrcpyArguments.make(serial: serial, model: model, mode: mode),
                log: log
            ) { [weak self] code in
                self?.didExit(serial: serial, id: id, code: code, log: log)
            }
            sessions[serial] = Session(id: id, model: model, mode: mode, process: process)
        } catch {
            caption = Self.launchFailedCaption(serial: serial, error: error)
        }
    }

    private func stop(serial: String) {
        sessions.removeValue(forKey: serial)?.process.terminate()
    }

    private func didExit(serial: String, id: UUID, code: Int32, log: URL) {
        guard sessions[serial]?.id == id else { return }
        sessions[serial] = nil
        if !Self.normalExitCodes.contains(code) {
            caption = Self.exitFailedCaption(serial: serial, log: log)
        }
    }
}

private extension MirrorController {
    struct Session {
        let id: UUID
        let model: String
        let mode: MirrorMode
        let process: any MirrorProcess
    }
}
