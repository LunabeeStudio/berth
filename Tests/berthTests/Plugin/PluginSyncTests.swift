import Foundation
import Testing

@Suite
struct PluginSyncTests {
    private static let root: URL = .init(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func text(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private static func json(_ path: String) throws -> [String: Any]? {
        let data: Data = try .init(contentsOf: root.appendingPathComponent(path))
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    @Test
    func `skill body is docs AGENTS verbatim after the frontmatter`() throws {
        let skill: String = try Self.text("claude-plugin/skills/berth/SKILL.md")
        let agents: String = try Self.text("docs/AGENTS.md")
        #expect(skill.hasPrefix("---\nname: berth\ndescription: "))
        #expect(skill.hasSuffix("\n---\n\n" + agents))
    }

    @Test
    func `plugin and marketplace versions match`() throws {
        let plugin: String = try #require(try Self.json("claude-plugin/.claude-plugin/plugin.json")?["version"] as? String)
        let marketplace: String? = (try Self.json(".claude-plugin/marketplace.json")?["plugins"] as? [[String: Any]])?.first?["version"] as? String
        #expect(marketplace == plugin)
    }
}
