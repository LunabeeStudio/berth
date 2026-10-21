import Foundation
import Testing

@Suite
struct PluginSyncTests {
    @Test
    func `skill body is docs AGENTS verbatim after the frontmatter`() throws {
        let skill: String = try RepoFile.text("claude-plugin/skills/berth/SKILL.md")
        let agents: String = try RepoFile.text("docs/AGENTS.md")
        #expect(skill.hasPrefix("---\nname: berth\ndescription: "))
        #expect(skill.hasSuffix("\n---\n\n" + agents))
    }

    @Test
    func `plugin and marketplace versions match`() throws {
        let plugin: String = try #require(try RepoFile.json("claude-plugin/.claude-plugin/plugin.json")?["version"] as? String)
        let marketplace: String? = (try RepoFile.json(".claude-plugin/marketplace.json")?["plugins"] as? [[String: Any]])?.first?["version"] as? String
        #expect(marketplace == plugin)
    }
}
