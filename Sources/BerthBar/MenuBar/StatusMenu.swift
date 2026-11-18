import AppKit

@MainActor
enum StatusMenu {
    static let repository: URL = .init(string: "https://github.com/LunabeeStudio/berth")!

    static func make(
        version: String,
        launchAtLogin: Bool,
        target: AnyObject,
        openRepository: Selector,
        toggleLaunchAtLogin: Selector,
        quit: Selector
    ) -> NSMenu {
        let menu: NSMenu = .init()
        let versionItem: NSMenuItem = .init(title: "berth \(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(.separator())
        menu.addItem(item("Open on GitHub", openRepository, target: target))
        let login: NSMenuItem = item("Launch at Login", toggleLaunchAtLogin, target: target)
        login.state = launchAtLogin ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(item("Quit berth-bar", quit, target: target, key: "q"))
        return menu
    }

    private static func item(_ title: String, _ selector: Selector, target: AnyObject, key: String = "") -> NSMenuItem {
        let menuItem: NSMenuItem = .init(title: title, action: selector, keyEquivalent: key)
        menuItem.target = target
        return menuItem
    }
}
