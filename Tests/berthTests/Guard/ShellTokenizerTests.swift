import Testing

@testable import berth

@Suite
struct ShellTokenizerTests {
    @Test
    func `splits words on whitespace`() {
        #expect(ShellTokenizer.segments(of: "adb  install\tapp.apk") == [["adb", "install", "app.apk"]])
    }

    @Test
    func `keeps quoted text as one word`() {
        #expect(ShellTokenizer.segments(of: #"echo "adb install" 'a b'"#) == [["echo", "adb install", "a b"]])
    }

    @Test
    func `joins adjacent quoted and bare text`() {
        #expect(ShellTokenizer.segments(of: #"adb -s "$S"x"#) == [["adb", "-s", "$Sx"]])
    }

    @Test
    func `keeps an empty quoted word`() {
        #expect(ShellTokenizer.segments(of: #"echo """#) == [["echo", ""]])
    }

    @Test
    func `backslash escapes a space and a quote`() {
        #expect(ShellTokenizer.segments(of: #"echo a\ b \"c"#) == [["echo", "a b", "\"c"]])
    }

    @Test
    func `backslash in double quotes escapes only special characters`() {
        #expect(ShellTokenizer.segments(of: #"echo "a\"b" "c\d""#) == [["echo", "a\"b", "c\\d"]])
    }

    @Test
    func `single quotes are literal`() {
        #expect(ShellTokenizer.segments(of: #"echo 'a\b;c'"#) == [["echo", #"a\b;c"#]])
    }

    @Test(arguments: [";", "&&", "||", "|", "&", "\n"])
    func `operators split segments`(separator: String) {
        #expect(ShellTokenizer.segments(of: "a b \(separator) c d") == [["a", "b"], ["c", "d"]])
    }

    @Test
    func `parentheses split segments`() {
        #expect(ShellTokenizer.segments(of: "X=$(berth claim); adb") == [["X=$"], ["berth", "claim"], ["adb"]])
    }

    @Test
    func `operators inside quotes do not split`() {
        #expect(ShellTokenizer.segments(of: #"echo "a && b""#) == [["echo", "a && b"]])
    }

    @Test(arguments: [#"echo "open"#, "echo 'open", #"echo trailing\"#])
    func `unbalanced input fails to parse`(line: String) {
        #expect(ShellTokenizer.segments(of: line) == nil)
    }

    @Test
    func `empty line has no segments`() {
        #expect(ShellTokenizer.segments(of: "  ;; ") == [])
    }
}
