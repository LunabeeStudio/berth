import Testing

@testable import BerthCore

@Suite
struct SemanticVersionTests {
    @Test
    func `parses with and without v prefix`() {
        #expect(SemanticVersion("v1.2.3")?.description == "1.2.3")
        #expect(SemanticVersion("0.10.0")?.description == "0.10.0")
    }

    @Test
    func `rejects dev and malformed text`() {
        #expect(SemanticVersion("dev") == nil)
        #expect(SemanticVersion("1.2") == nil)
        #expect(SemanticVersion("1.2.3-rc1") == nil)
        #expect(SemanticVersion("") == nil)
    }

    @Test
    func `compares numerically not lexically`() throws {
        let nine: SemanticVersion = try #require(.init("0.9.0"))
        let ten: SemanticVersion = try #require(.init("0.10.0"))
        #expect(nine < ten)
        #expect(try #require(SemanticVersion("1.0.0")) > ten)
    }
}
