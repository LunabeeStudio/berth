import AppKit
import SwiftUI

@MainActor
final class AppKitPairWindow: NSObject, PairWindowing, NSWindowDelegate {
    private let window: NSWindow
    private let onClose: () -> Void

    init(flow: PairFlow, onClose: @escaping () -> Void) {
        let content: NSHostingController<PairView> = .init(rootView: PairView(flow: flow))
        content.sizingOptions = .preferredContentSize
        window = NSWindow(contentViewController: content)
        window.title = PairCopy.windowTitle
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        self.onClose = onClose
        super.init()
        window.delegate = self
        window.center()
    }

    func bringToFront() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
