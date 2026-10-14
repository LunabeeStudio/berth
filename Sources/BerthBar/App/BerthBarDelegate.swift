import AppKit

@MainActor
final class BerthBarDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = .init(model: .init())
    }
}
