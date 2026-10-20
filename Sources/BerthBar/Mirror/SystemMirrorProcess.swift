import Foundation

final class SystemMirrorProcess: MirrorProcess {
    private let process: Process

    init(process: Process) {
        self.process = process
    }

    var pid: Int32 { process.processIdentifier }

    func terminate() {
        process.terminate()
    }
}
