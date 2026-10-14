import Testing

@testable import berth

@Suite
struct ShellTokenizerHeredocAndCommentTests {
    @Test
    func `heredoc body is skipped and the command before it kept`() {
        #expect(ShellTokenizer.segments(of: "cat > f <<'EOF'\nadb install x\nEOF\nls") == [["cat", ">", "f"], ["ls"]])
    }

    @Test
    func `unterminated heredoc fails to parse`() {
        #expect(ShellTokenizer.segments(of: "cat <<EOF\nbody") == nil)
    }

    @Test
    func `here-string is not a heredoc`() {
        #expect(ShellTokenizer.segments(of: "cat <<< x") == [["cat", "<<<", "x"]])
    }

    @Test
    func `arithmetic shift is not a heredoc`() {
        #expect(ShellTokenizer.segments(of: "echo $((1<<2)); adb install x") == [["echo", "$"], ["1<<2"], ["adb", "install", "x"]])
    }

    @Test
    func `heredoc body attaches to the command that owns it`() {
        let commands: [ShellCommand]? = ShellTokenizer.commands(of: "cat <<EOF | sh\nadb install x\nEOF")
        #expect(commands == [
            .init(words: ["cat"], heredoc: "adb install x", isPiped: false),
            .init(words: ["sh"], heredoc: nil, isPiped: true),
        ])
    }

    @Test
    func `or operator is not a pipe`() {
        #expect(ShellTokenizer.commands(of: "a || b")?.map(\.isPiped) == [false, false])
    }

    @Test
    func `comment drops the rest of the line only`() {
        #expect(ShellTokenizer.segments(of: "ls # a ; b\necho c#d") == [["ls"], ["echo", "c#d"]])
    }
}
