import Foundation

/// Decides, poll after poll, when the daemon may replace itself with a changed executable on disk.
struct ReexecMonitor: Sendable {
    typealias IdleGate = @Sendable (@escaping @Sendable () -> Void) async -> Bool

    private var watch: ExecutableWatch
    private let verify: @Sendable () async -> Bool
    private let performIfIdle: IdleGate
    private let exec: @Sendable () -> Void
    private let log: @Sendable (String) -> Void
    private var verified: Bool = false
    private var rejectionLogged: Bool = false
    private var execFailed: Bool = false

    /// - Parameter exec: replaces the process; returning means it failed.
    init(
        watch: ExecutableWatch,
        verify: @escaping @Sendable () async -> Bool,
        performIfIdle: @escaping IdleGate,
        exec: @escaping @Sendable () -> Void,
        log: @escaping @Sendable (String) -> Void
    ) {
        self.watch = watch
        self.verify = verify
        self.performIfIdle = performIfIdle
        self.exec = exec
        self.log = log
    }

    mutating func poll() async {
        guard watch.hasSettledChange() else {
            verified = false
            rejectionLogged = false
            execFailed = false
            return
        }
        guard !execFailed else { return }
        if !verified { verified = await verify() }
        guard verified else {
            if !rejectionLogged { log("new executable fails verification, not restarting into it") }
            rejectionLogged = true
            return
        }
        let exec: @Sendable () -> Void = exec
        let log: @Sendable (String) -> Void = log
        let ran: Bool = await performIfIdle {
            log("re-exec after binary change")
            exec()
        }
        execFailed = ran
    }
}
