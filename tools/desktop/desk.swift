// Desktop proof helper for berth-bar: reads the desktop and captures a pid's window, no input, no focus change.
// Run: xcrun swift tools/desktop/desk.swift desk-state | window-id <pid> | capture <pid> <out.png>
// Exit: 0 ok, 1 no window or failure, 2 bad usage.

import AppKit
import CoreGraphics
import Foundation

let usage: String = "usage: desk.swift desk-state | window-id <pid> | capture <pid> <out.png>"

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func windowID(ownedBy pid: Int32) -> CGWindowID? {
    let windows: [[String: Any]] = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
    let candidates: [(id: CGWindowID, area: Double)] = windows.compactMap { window in
        guard
            window[kCGWindowOwnerPID as String] as? Int32 == pid,
            let id: CGWindowID = window[kCGWindowNumber as String] as? CGWindowID,
            let boundsDict: NSDictionary = window[kCGWindowBounds as String] as? NSDictionary,
            let bounds: CGRect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
        else { return nil }
        return (id, Double(bounds.width * bounds.height))
    }
    return candidates.max(by: { $0.area < $1.area })?.id
}

func parsePid(_ text: String) -> Int32 {
    guard let pid: Int32 = Int32(text) else { fail(usage, code: 2) }
    return pid
}

let args: [String] = Array(CommandLine.arguments.dropFirst())

switch (args.first, args.count) {
case ("desk-state", 1):
    let front: NSRunningApplication? = NSWorkspace.shared.frontmostApplication
    let cursor: CGPoint? = CGEvent(source: nil)?.location
    let state: [String: Any] = [
        "frontmostPid": front.map { Int($0.processIdentifier) } ?? NSNull(),
        "frontmostName": front?.localizedName ?? NSNull(),
        "cursor": cursor.map { ["x": $0.x, "y": $0.y] } ?? NSNull(),
    ]
    do {
        let data: Data = try JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    } catch {
        fail("desk-state: \(error)", code: 1)
    }
case ("window-id", 2):
    guard let id: CGWindowID = windowID(ownedBy: parsePid(args[1])) else { exit(1) }
    print(id)
case ("capture", 3):
    let pid: Int32 = parsePid(args[1])
    guard let id: CGWindowID = windowID(ownedBy: pid) else { fail("no on-screen window for pid \(pid)", code: 1) }
    let process: Process = .init()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    process.arguments = ["-l", String(id), "-o", "-x", args[2]]
    do {
        try process.run()
    } catch {
        fail("capture: \(error)", code: 1)
    }
    process.waitUntilExit()
    exit(process.terminationStatus == 0 ? 0 : 1)
default:
    fail(usage, code: 2)
}
