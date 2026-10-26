import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let model: StatusModel
    private let launchAtLogin: LaunchAtLogin
    private let autoUpdate: AutoUpdateSetting
    private let launcher: EmulatorLauncher
    private let mirror: MirrorController
    private let item: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover: NSPopover = .init()
    private var shownSymbol: String?
    private var shownTitle: String?

    init(model: StatusModel, launchAtLogin: LaunchAtLogin, autoUpdate: AutoUpdateSetting, launcher: EmulatorLauncher, mirror: MirrorController) {
        self.model = model
        self.launchAtLogin = launchAtLogin
        self.autoUpdate = autoUpdate
        self.launcher = launcher
        self.mirror = mirror
        super.init()
        let content: NSHostingController<StatusPanel> = .init(rootView: StatusPanel(model: model, launchAtLogin: launchAtLogin, autoUpdate: autoUpdate, launcher: launcher, mirror: mirror))
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
            autoUpdate.refresh()
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func refresh() {
        let (state, now): (StatusState, Date) = withObservationTracking {
            (model.state, model.now)
        } onChange: { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        let symbol: String = MenuBarLabel.symbolName(for: state, now: now)
        if symbol != shownSymbol {
            shownSymbol = symbol
            item.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "berth")
        }
        let title: String = MenuBarLabel.text(for: state).map { " \($0)" } ?? ""
        if title != shownTitle {
            shownTitle = title
            item.button?.title = title
        }
    }
}
