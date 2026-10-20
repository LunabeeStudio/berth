import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let model: StatusModel
    private let launchAtLogin: LaunchAtLogin
    private let launcher: EmulatorLauncher
    private let mirror: MirrorController
    private let item: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover: NSPopover = .init()

    init(model: StatusModel, launchAtLogin: LaunchAtLogin, launcher: EmulatorLauncher, mirror: MirrorController) {
        self.model = model
        self.launchAtLogin = launchAtLogin
        self.launcher = launcher
        self.mirror = mirror
        super.init()
        let content: NSHostingController<StatusPanel> = .init(rootView: StatusPanel(model: model, launchAtLogin: launchAtLogin, launcher: launcher, mirror: mirror))
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content
        popover.behavior = .transient
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.imagePosition = .imageLeading
        refresh()
    }

    @objc private func toggle() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            launchAtLogin.refresh()
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func refresh() {
        let state: StatusState = withObservationTracking {
            model.state
        } onChange: { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        item.button?.image = NSImage(systemSymbolName: MenuBarLabel.symbolName(for: state), accessibilityDescription: "berth")
        item.button?.title = MenuBarLabel.text(for: state).map { " \($0)" } ?? ""
    }
}
