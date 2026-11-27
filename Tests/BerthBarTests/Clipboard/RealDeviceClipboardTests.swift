import BerthCore
import Foundation
import Testing

@testable import BerthBar

@MainActor
@Suite(.serialized)
struct RealDeviceClipboardTests {
    nonisolated private static let serial: String? = ProcessInfo.processInfo.environment["BERTH_CLIPBOARD_SERIAL"]
    nonisolated private static let expected: String? = ProcessInfo.processInfo.environment["BERTH_CLIPBOARD_EXPECTED"]

    @Test(.enabled(if: serial != nil, "set BERTH_CLIPBOARD_SERIAL=<serial> to read a real device clipboard (BERTH_CLIPBOARD_EXPECTED=<text> to assert it)"))
    func `reads the clipboard of a real device and leaves no forward and no server behind`() async throws {
        let serial: String = try #require(Self.serial)
        let before: String = try await Self.power(serial)
        let forwardsBefore: String = try await Self.adb(["forward", "--list"])
        let serversBefore: [String] = try await Self.servers(serial)

        let started: ContinuousClock.Instant = .now
        let text: String? = try await ScrcpyDeviceClipboard().text(serial: serial)
        let elapsed: Duration = .now - started

        print("[clipboard-proof] \(serial) read in \(elapsed): \(text.map { "\($0.count) characters, \($0.utf8.count) bytes" } ?? "nil")")
        if let expected = Self.expected {
            #expect(text == expected)
        }
        let after: String = try await Self.power(serial)
        print("[clipboard-proof] power before: \(before) after: \(after)")
        #expect(before == after)
        let forwardsAfter: String = try await Self.adb(["forward", "--list"])
        print("[clipboard-proof] forwards before: \(forwardsBefore.isEmpty ? "none" : forwardsBefore)")
        print("[clipboard-proof] forwards after: \(forwardsAfter.isEmpty ? "none" : forwardsAfter)")
        #expect(forwardsAfter == forwardsBefore)
        let serversAfter: [String] = try await Self.servers(serial)
        print("[clipboard-proof] scrcpy servers before: \(serversBefore.count) after: \(serversAfter.count)")
        #expect(serversAfter == serversBefore)
    }

    @Test(.enabled(if: serial != nil, "set BERTH_CLIPBOARD_SERIAL=<serial> to read a real device clipboard"))
    func `a read that runs out of time ends with a timeout and leaves no forward and no server behind`() async throws {
        let serial: String = try #require(Self.serial)
        let forwardsBefore: String = try await Self.adb(["forward", "--list"])
        let serversBefore: [String] = try await Self.servers(serial)

        for milliseconds in [20, 60, 100, 130, 160, 190, 220] {
            let started: ContinuousClock.Instant = .now
            let outcome: String
            do {
                let text: String? = try await ScrcpyDeviceClipboard(timeout: .milliseconds(milliseconds)).text(serial: serial)
                outcome = "read \(text?.count ?? 0) characters"
            } catch {
                outcome = "\(error)"
            }
            print("[clipboard-proof] timeout \(milliseconds) ms: \(outcome) after \(ContinuousClock.now - started)")
            #expect(try await Self.adb(["forward", "--list"]) == forwardsBefore)
            #expect(try await Self.servers(serial) == serversBefore)
        }
    }

    @Test(.enabled(if: serial != nil, "set BERTH_CLIPBOARD_SERIAL=<serial> to read a real device clipboard"))
    func `a click on a real device fills a fake pasteboard and shows the caption`() async throws {
        let serial: String = try #require(Self.serial)
        let pasteboard: FakeMacPasteboard = .init(content: "mac before")
        let actions: ClipboardActions = .init(pasteboard: pasteboard)

        await actions.copy(serial: serial).value

        print("[clipboard-proof] caption: \(actions.caption ?? "nil") pasteboard: \(pasteboard.content.map { "\($0.count) characters" } ?? "nil") writes: \(pasteboard.writes)")
        if let expected = Self.expected {
            #expect(pasteboard.content == expected)
            #expect(actions.caption == "Copied clipboard of \(serial)")
        }
    }

    private static func servers(_ serial: String) async throws -> [String] {
        try await adb(["-s", serial, "shell", "ps -A -o ARGS"]).split(whereSeparator: \.isNewline).map(String.init).filter { $0.contains("com.genymobile.scrcpy.Server") }
    }

    private static func power(_ serial: String) async throws -> String {
        let dump: String = try await adb(["-s", serial, "shell", "dumpsys power"])
        return dump.split(whereSeparator: \.isNewline).map(String.init).first { $0.contains("mWakefulness=") }?.trimmingCharacters(in: .whitespaces) ?? "unknown"
    }

    private static func adb(_ arguments: [String]) async throws -> String {
        try await Shell.run(Config.defaultADBPath(), arguments, timeout: .seconds(15)).trimmedOutput
    }
}
