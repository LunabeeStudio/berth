import AppKit

@MainActor
final class BerthBarDelegate: NSObject, NSApplicationDelegate {
    private let mirror: MirrorController = .init()
    private var controller: StatusItemController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model: StatusModel = .init()
        mirror.observe(model)
        controller = .init(model: model, launchAtLogin: .init(), autoUpdate: .init(), launcher: .init(), mirror: mirror)
    }

    func applicationWillTerminate(_ notification: Notification) {
        mirror.stopAll()
    }
}
