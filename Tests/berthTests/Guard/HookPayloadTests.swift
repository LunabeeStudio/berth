import Foundation
import Testing

@testable import berth

@Suite
struct HookPayloadTests {
    private static func command(_ json: String) -> String? {
        HookPayload.command(from: Data(json.utf8))
    }

    @Test
    func `extracts the command of a Bash call`() {
        let json: String = #"{"session_id":"s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"adb shell echo hi","description":"x"}}"#
        #expect(Self.command(json) == "adb shell echo hi")
    }

    @Test
    func `ignores a non-Bash tool`() {
        #expect(Self.command(#"{"tool_name":"Edit","tool_input":{"command":"adb install x"}}"#) == nil)
    }

    @Test
    func `ignores malformed JSON`() {
        #expect(Self.command("{not json") == nil)
    }

    @Test
    func `ignores a Bash call without a command`() {
        #expect(Self.command(#"{"tool_name":"Bash","tool_input":{}}"#) == nil)
    }
}
