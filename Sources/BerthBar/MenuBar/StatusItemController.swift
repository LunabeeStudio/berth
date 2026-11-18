import AppKit
import BerthCore
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let model: StatusModel
    private let launchAtLogin: LaunchAtLogin
    private let autoUpdate: AutoUpdateSetting
    private let launcher: EmulatorLauncher
    private let avdList: AVDList
    private let mirror: MirrorController
    private let item: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover: NSPopover = .init()
    private var shownSymbol: String?
    private var shownTitle: String?

    init(model: StatusModel, launchAtLogin: LaunchAtLogin, autoUpdate: AutoUpdateSetting, launcher: EmulatorLauncher, avdList: AVDList, mirror: MirrorController) {
        self.model = model
        self.launchAtLogin = launchAtLogin
        self.autoUpdate = autoUpdate
        self.launcher = launcher
        self.avdList = avdList
        self.mirror = mirror
        super.init()
        let content: NSHostingController<StatusPanel> = .init(rootView: StatusPanel(model: model, launchAtLogin: launchAtLogin, autoUpdate: autoUpdate, launcher: launcher, avdList: avdList, mirror: mirror))
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content
        popover.behavior = .transient
        item.button?.target = self
        item.button?.action = #selector(click)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.imagePosition = .imageLeading
        // VoiceOver presses the button without a right click, so the menu needs its own action.
        item.button?.setAccessibilityCustomActions([.init(name: "Show Menu", target: self, selector: #selector(showMenuForAccessibility))])
        refresh()
    }

    @objc private func click() {
        let event: NSEvent? = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            toggle()
        }
    }

    private func showMenu() {
        guard let button = item.button else { return }
        if popover.isShown { popover.performClose(nil) }
        launchAtLogin.refresh()
        let menu: NSMenu = StatusMenu.make(
            version: BerthVersion.current,
            launchAtLogin: launchAtLogin.isEnabled,
            target: self,
            openRepository: #selector(openRepository),
            toggleLaunchAtLogin: #selector(toggleLaunchAtLogin),
            quit: #selector(quit)
        )
        // Attached for one click, so the system places the menu and highlights the button. The click returns once the menu
        // closes, and a left click then opens the popover again.
        item.menu = menu
        button.performClick(nil)
        item.menu = nil
    }

    @objc private func showMenuForAccessibility() -> Bool {
        showMenu()
        return true
    }

    @objc private func openRepository() {
        NSWorkspace.shared.open(StatusMenu.repository)
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLogin.isEnabled.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func toggle() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            launchAtLogin.refresh()
            autoUpdate.refresh()
            Task { await avdList.refresh() }
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
