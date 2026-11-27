@testable import BerthBar

@MainActor
final class FakeMacPasteboard: MacPasteboard {
    private(set) var content: String?
    private(set) var writes: Int = 0

    init(content: String? = nil) {
        self.content = content
    }

    func replaceContents(with text: String) {
        content = text
        writes += 1
    }
}
