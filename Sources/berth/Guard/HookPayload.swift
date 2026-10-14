import Foundation

struct HookPayload: Decodable {
    struct ToolInput: Decodable {
        let command: String?
    }

    let toolName: String
    let toolInput: ToolInput?

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case toolInput = "tool_input"
    }

    static func command(from data: Data) -> String? {
        guard
            let payload = try? JSONDecoder().decode(HookPayload.self, from: data),
            payload.toolName == "Bash"
        else { return nil }
        return payload.toolInput?.command
    }
}
