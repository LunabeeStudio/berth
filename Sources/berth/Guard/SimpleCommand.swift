struct SimpleCommand {
    let assignments: [String: String]
    let name: String?
    let arguments: [String]

    init(words: [String]) {
        var assignments: [String: String] = [:]
        var rest: ArraySlice<String> = words[...]
        var name: String?

        while let word = rest.first {
            let candidate: String = Self.basename(word)
            if let (key, value) = Self.assignment(word) {
                assignments[key] = value
                rest = rest.dropFirst()
            } else if candidate == "for" {
                rest = []
            } else if Self.keywords.contains(word) {
                rest = rest.dropFirst()
            } else if let wrapper = Self.wrappers[candidate] {
                rest = wrapper.commandWords(after: rest.dropFirst())
            } else {
                name = candidate
                rest = rest.dropFirst()
                break
            }
        }
        self.assignments = assignments
        self.name = name
        self.arguments = Array(rest)
    }

    static func assignment(_ word: String) -> (String, String)? {
        guard let equals = word.firstIndex(of: "="), let first = word.first, first != "=", !first.isNumber else { return nil }
        let key: Substring = word[..<equals]
        guard key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { return nil }
        return (String(key), String(word[word.index(after: equals)...]))
    }

    static func basename(_ word: String) -> String {
        word.split(separator: "/").last.map(String.init) ?? word
    }
}

private extension SimpleCommand {
    static let keywords: Set<String> = ["do", "then", "else", "elif", "if", "while", "until", "!", "{"]

    static let wrappers: [String: Wrapper] = [
        "env": .init(valueOptions: ["-u", "-C", "-S"]),
        "sudo": .init(valueOptions: ["-u", "-g", "-h", "-p", "-C", "-D", "-R", "-T"]),
        "exec": .init(),
        "nohup": .init(),
        "time": .init(),
        "command": .init(lookupFlags: ["-v", "-V"]),
        "nice": .init(valueOptions: ["-n"]),
        "timeout": .init(valueOptions: ["-s", "-k"], skipsLeadingNumber: true),
        "rtk": .init(subcommand: "proxy"),
        "xargs": .init(valueOptions: ["-n", "-I", "-L", "-P", "-s", "-d", "-E", "-a"]),
        "xcrun": .init(valueOptions: ["--sdk", "-sdk", "--toolchain", "-toolchain"]),
    ]
}
