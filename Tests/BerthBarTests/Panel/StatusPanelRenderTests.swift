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

    private static func render(_ state: StatusState, named name: String, appearance: NSAppearance.Name = .aqua) throws -> NSBitmapImageRep {
        let model: StatusModel = .init(state: state, now: now)
        let login: LaunchAtLogin = .init(
            agent: .temporary(label: "com.berth.bar.render"),
            executable: "/opt/berth-bar",
            environment: [:]
        )
        let host: NSHostingView<StatusPanel> = .init(rootView: StatusPanel(model: model, launchAtLogin: login))
        host.appearance = NSAppearance(named: appearance)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let image: NSBitmapImageRep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        try writePNG(image, named: name)
        return image
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
        #expect(image.size.width == 620)
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
}
