import AppKit
import Foundation
import SwiftUI
import Testing

@testable import BerthBar
@testable import BerthCore

@MainActor
@Suite
struct StatusPanelRenderTests {
    private static let now: Date = .init(timeIntervalSince1970: 1_800_000_000)

    private static func busy() -> StatusState {
        let lease: Lease = .mock(
            owner: .mock(pid: 4242, name: "claude"),
            label: "demo",
            grantedAt: now.addingTimeInterval(-9),
            expiresAt: now.addingTimeInterval(59 * 60)
        )
        let slot: Slot = .mock(serial: "emulator-5554", model: "Pixel_8", state: .leased, lease: lease)
        let waiter: WaiterInfo = .mock(
            owner: .mock(pid: 4343, name: "codex"),
            label: "checkout",
            model: "Pixel_Tablet",
            enqueuedAt: now.addingTimeInterval(-5)
        )
        return .live(.mock(slots: [slot], queue: [waiter], generatedAt: now))
    }

    private static func windowed() -> StatusState {
        let lease: Lease = .mock(
            owner: .mock(pid: 99, name: "berth-bar"),
            label: "you",
            grantedAt: now.addingTimeInterval(-120),
            expiresAt: .distantFuture,
            manual: true
        )
        let own: Slot = .mock(serial: "emulator-5556", model: "Pixel_9", state: .leased, lease: lease, windowed: true)
        let agent: Slot = .mock(
            serial: "emulator-5554",
            model: "Pixel_8",
            state: .leased,
            lease: .mock(owner: .mock(pid: 4242, name: "claude"), label: "demo", grantedAt: now.addingTimeInterval(-9), expiresAt: now.addingTimeInterval(59 * 60))
        )
        let pool: [PoolEntry] = [PoolEntry(name: "Pixel_8", maxInstances: 1), PoolEntry(name: "Pixel_9", maxInstances: 1), PoolEntry(name: "iPhone 17", platform: .ios, maxInstances: 1)]
        return .live(.mock(slots: [agent, own], pool: pool, generatedAt: now))
    }

    private static func mirrorable() -> StatusState {
        let lease: Lease = .mock(owner: .mock(pid: 4242, name: "claude"), label: "demo", grantedAt: now.addingTimeInterval(-9), expiresAt: now.addingTimeInterval(59 * 60))
        let free: Slot = .mock(serial: "emulator-5554", model: "Pixel_8", state: .free)
        let leased: Slot = .mock(serial: "emulator-5556", model: "Pixel_9", state: .leased, lease: lease)
        let windowed: Slot = .mock(serial: "emulator-5558", model: "Pixel_9", state: .leased, lease: .mock(owner: .mock(pid: 99, name: "berth-bar"), label: "you", grantedAt: now.addingTimeInterval(-120), expiresAt: .distantFuture, manual: true), windowed: true)
        let simulator: Slot = .mock(serial: "UDID-1", model: "iPhone 17", state: .free)
        let resetting: Slot = .mock(serial: "emulator-5560", model: "Pixel_8", state: .resetting)
        let pool: [PoolEntry] = [.init(name: "Pixel_8", maxInstances: 2), .init(name: "Pixel_9", maxInstances: 2), .init(name: "iPhone 17", platform: .ios, maxInstances: 1)]
        return .live(.mock(slots: [free, leased, windowed, simulator, resetting], pool: pool, generatedAt: now))
    }

    private static func render(
        _ state: StatusState,
        named name: String,
        appearance: NSAppearance.Name = .aqua,
        mirror: MirrorController = .init(),
        autoUpdate: AutoUpdateSetting? = nil
    ) throws -> NSBitmapImageRep {
        let model: StatusModel = .init(state: state, now: now)
        let login: LaunchAtLogin = .init(
            agent: .temporary(label: "com.berth.bar.render"),
            executable: "/opt/berth-bar",
            environment: [:]
        )
        let setting: AutoUpdateSetting = try autoUpdate ?? Self.setting(autoUpdate: true)
        let host: NSHostingView<StatusPanel> = .init(rootView: StatusPanel(model: model, launchAtLogin: login, autoUpdate: setting, launcher: .init(), mirror: mirror))
        host.appearance = NSAppearance(named: appearance)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let image: NSBitmapImageRep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        try writePNG(image, named: name)
        return image
    }

    private static func setting(autoUpdate: Bool) throws -> AutoUpdateSetting {
        let url: URL = FileManager.default.temporaryDirectory.appendingPathComponent("berth-render-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Config(autoUpdate: autoUpdate).save(to: url)
        return .init(configURL: url)
    }

    private static func writePNG(_ image: NSBitmapImageRep, named name: String) throws {
        guard let directory: String = ProcessInfo.processInfo.environment["BERTH_PANEL_PNG_DIR"] else { return }
        let url: URL = .init(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let data: Data = try #require(image.representation(using: .png, properties: [:]))
        try data.write(to: url.appendingPathComponent("\(name).png"))
    }

    private static func expectPanelSized(_ image: NSBitmapImageRep) {
        #expect(image.pixelsHigh > 0)
        #expect(image.size.width == 650)
    }

    private static func expectOpaque(_ image: NSBitmapImageRep) {
        let translucent: Int = (0 ..< image.pixelsHigh).reduce(0) { total, y in
            total + (0 ..< image.pixelsWide).count { x in image.colorAt(x: x, y: y)?.alphaComponent != 1 }
        }
        #expect(translucent == 0)
    }

    @Test
    func `connecting renders the panel`() throws {
        Self.expectPanelSized(try Self.render(.connecting, named: "connecting"))
    }

    @Test
    func `disconnected renders the panel`() throws {
        Self.expectPanelSized(try Self.render(.disconnected("socket not found at /tmp/bb5/berth.sock"), named: "disconnected"))
    }

    @Test
    func `live with no emulator and no queue renders the panel`() throws {
        Self.expectPanelSized(try Self.render(.live(.mock(generatedAt: Self.now)), named: "live-empty"))
    }

    @Test(arguments: [(NSAppearance.Name.aqua, "live-busy"), (.darkAqua, "live-busy-dark")])
    func `panel is opaque in every appearance`(appearance: NSAppearance.Name, name: String) throws {
        let image: NSBitmapImageRep = try Self.render(Self.busy(), named: name, appearance: appearance)
        Self.expectPanelSized(image)
        Self.expectOpaque(image)
    }

    @Test
    func `unstable adb renders the notice in the panel`() throws {
        let state: StatusState = .live(.mock(generatedAt: Self.now, adbRestartedAt: Self.now.addingTimeInterval(-12)))
        Self.expectPanelSized(try Self.render(state, named: "live-adb-unstable"))
    }

    @Test
    func `live with a windowed emulator and android pool entries renders the panel`() throws {
        Self.expectPanelSized(try Self.render(Self.windowed(), named: "live-windowed"))
    }

    @Test(arguments: [(NSAppearance.Name.aqua, "live-mirror"), (.darkAqua, "live-mirror-dark")])
    func `mirror button rows render in every appearance`(appearance: NSAppearance.Name, name: String) throws {
        Self.expectPanelSized(try Self.render(Self.mirrorable(), named: name, appearance: appearance))
    }

    @Test(arguments: [(NSAppearance.Name.aqua, "auto-update-off"), (.darkAqua, "auto-update-off-dark")])
    func `auto update unchecked renders in every appearance`(appearance: NSAppearance.Name, name: String) throws {
        let setting: AutoUpdateSetting = try Self.setting(autoUpdate: false)
        Self.expectPanelSized(try Self.render(.connecting, named: name, appearance: appearance, autoUpdate: setting))
    }

    @Test(arguments: [(NSAppearance.Name.aqua, "auto-update-disabled"), (.darkAqua, "auto-update-disabled-dark")])
    func `auto update disabled without a config renders in every appearance`(appearance: NSAppearance.Name, name: String) throws {
        let missing: URL = FileManager.default.temporaryDirectory.appendingPathComponent("berth-missing-\(UUID().uuidString).json")
        let setting: AutoUpdateSetting = .init(configURL: missing)
        Self.expectPanelSized(try Self.render(.connecting, named: name, appearance: appearance, autoUpdate: setting))
    }

    @Test
    func `live with a mirror caption renders the panel`() throws {
        let mirror: MirrorController = .init(
            launcher: FakeMirrorLauncher(),
            locator: .init(environment: [:], fallbackDirectories: [])
        )
        mirror.open(.mock(), platform: .android)

        Self.expectPanelSized(try Self.render(Self.mirrorable(), named: "live-mirror-caption", mirror: mirror))
        #expect(mirror.caption == "scrcpy not found: brew install scrcpy")
    }
}
