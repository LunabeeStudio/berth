import AppKit
import Testing

@testable import BerthBar

@MainActor
@Suite
struct StatusMenuTests {
    private final class Target: NSObject {
        @objc func openRepository() {}
        @objc func toggleLaunchAtLogin() {}
        @objc func quit() {}
    }

    private static func menu(version: String = "1.2.3", launchAtLogin: Bool = false, target: Target = .init()) -> NSMenu {
        StatusMenu.make(
            version: version,
            launchAtLogin: launchAtLogin,
            target: target,
            openRepository: #selector(Target.openRepository),
            toggleLaunchAtLogin: #selector(Target.toggleLaunchAtLogin),
            quit: #selector(Target.quit)
        )
    }

    @Test
    func `items come in order with separators`() {
        let items: [NSMenuItem] = Self.menu().items
        #expect(items.map { $0.isSeparatorItem ? "-" : $0.title } == ["berth 1.2.3", "-", "Open on GitHub", "Launch at Login", "-", "Quit berth-bar"])
    }

    @Test
    func `version item is disabled`() {
        #expect(Self.menu(version: "dev").items[0].title == "berth dev")
        #expect(!Self.menu().items[0].isEnabled)
    }

    @Test
    func `launch at login checkmark follows the state`() {
        #expect(Self.menu(launchAtLogin: true).items[3].state == .on)
        #expect(Self.menu(launchAtLogin: false).items[3].state == .off)
    }

    @Test
    func `quit has the q key equivalent`() {
        #expect(Self.menu().items[5].keyEquivalent == "q")
    }

    @Test
    func `actionable items have an action and the target`() {
        let target: Target = .init()
        let items: [NSMenuItem] = Self.menu(target: target).items
        for index in [2, 3, 5] {
            #expect(items[index].action != nil)
            #expect(items[index].target === target)
        }
    }

    @Test
    func `repository points at the berth GitHub project`() {
        #expect(StatusMenu.repository.absoluteString == "https://github.com/LunabeeStudio/berth")
    }
}
