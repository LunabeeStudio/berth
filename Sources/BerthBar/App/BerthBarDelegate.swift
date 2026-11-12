import AppKit

@MainActor
final class BerthBarDelegate: NSObject, NSApplicationDelegate {
    private let mirror: MirrorController = .init()
    private var controller: StatusItemController?
    private var terminationSignal: DispatchSourceSignal?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        signal(SIGTERM, SIG_IGN)
        let source: DispatchSourceSignal = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApp.terminate(nil) }
        source.resume()
        terminationSignal = source
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model: StatusModel = .init()
        mirror.observe(model)
        controller = .init(model: model, launchAtLogin: .init(), autoUpdate: .init(), launcher: .init(), avdList: .init(), mirror: mirror)
    }

    func applicationWillTerminate(_ notification: Notification) {
        mirror.stopAll()
    }
}
