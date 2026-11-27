import AppKit
import Foundation
import Testing

enum PanelPNG {
    static func write(_ image: NSBitmapImageRep, named name: String) throws {
        guard let directory: String = ProcessInfo.processInfo.environment["BERTH_PANEL_PNG_DIR"] else { return }
        let url: URL = .init(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let data: Data = try #require(image.representation(using: .png, properties: [:]))
        try data.write(to: url.appendingPathComponent("\(name).png"))
    }
}
