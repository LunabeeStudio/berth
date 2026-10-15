enum ShellTokenizer {
    static func commands(of line: String) -> [ShellCommand]? {
        var lexer: Lexer = .init(characters: Array(line))
        return lexer.run()
    }

    static func segments(of line: String) -> [[String]]? {
        commands(of: line)?.map(\.words)
    }
}

private extension ShellTokenizer {
    struct Lexer {
        enum Quote {
            case single
            case double
        }

        struct PendingHeredoc {
            let delimiter: String
            let owner: Int
        }

        let characters: [Character]
        var index: Int = 0
        var commands: [ShellCommand] = []
        var words: [String] = []
        var word: String?
        var quote: Quote?
        var pending: [PendingHeredoc] = []
        var expectsDelimiter: Bool = false
        var ownsHeredoc: Bool = false
        var nextIsPiped: Bool = false
        var arithmeticDepth: Int = 0

        init(characters: [Character]) {
            self.characters = characters
        }

        mutating func run() -> [ShellCommand]? {
            while index < characters.count {
                let character: Character = characters[index]
                index += 1
                guard consume(character) else { return nil }
            }
            guard quote == nil, pending.isEmpty, !expectsDelimiter else { return nil }
            endCommand()
            return commands
        }

        private mutating func consume(_ character: Character) -> Bool {
            switch quote {
            case .single:
                if character == "'" { quote = nil } else { word?.append(character) }
                return true
            case .double:
                return consumeInDoubleQuotes(character)
            case nil:
                return consumeUnquoted(character)
            }
        }

        private mutating func consumeInDoubleQuotes(_ character: Character) -> Bool {
            switch character {
            case "\"":
                quote = nil
            case "\\":
                guard let escaped = nextCharacter() else { return false }
                if !"\"\\$`".contains(escaped) { word?.append(character) }
                word?.append(escaped)
            default:
                word?.append(character)
            }
            return true
        }

        private mutating func consumeUnquoted(_ character: Character) -> Bool {
            switch character {
            case "'", "\"":
                quote = character == "'" ? .single : .double
                word = word ?? ""
            case "\\":
                guard let escaped = nextCharacter() else { return false }
                if escaped != "\n" { word = (word ?? "") + String(escaped) }
            case "#" where word == nil:
                index = characters[index...].firstIndex(of: "\n") ?? characters.count
            case "<" where startsHeredoc():
                endWord()
                index += characters[index...].starts(with: "<-") ? 2 : 1
                expectsDelimiter = true
            case "\n":
                endCommand()
                return readHeredocBodies()
            case "|":
                let isOr: Bool = index < characters.count && characters[index] == "|"
                if isOr { index += 1 }
                endCommand()
                nextIsPiped = !isOr && !commands.isEmpty
            case "(":
                if index >= 2, characters[index - 2] == "(" { arithmeticDepth += 1 }
                endCommand()
            case ")":
                if arithmeticDepth > 0, index < characters.count, characters[index] == ")" {
                    index += 1
                    arithmeticDepth -= 1
                }
                endCommand()
            case ";", "&":
                endCommand()
            case " ", "\t":
                endWord()
            default:
                word = (word ?? "") + String(character)
            }
            return true
        }

        private mutating func nextCharacter() -> Character? {
            guard index < characters.count else { return nil }
            defer { index += 1 }
            return characters[index]
        }

        private func startsHeredoc() -> Bool {
            guard arithmeticDepth == 0, index < characters.count, characters[index] == "<" else { return false }
            let followsAngle: Bool = index >= 2 && characters[index - 2] == "<"
            let precedesAngle: Bool = index + 1 < characters.count && characters[index + 1] == "<"
            return !followsAngle && !precedesAngle
        }

        private mutating func endWord() {
            guard let finished = word else { return }
            word = nil
            if expectsDelimiter {
                pending.append(.init(delimiter: finished, owner: commands.count))
                ownsHeredoc = true
                expectsDelimiter = false
            } else {
                words.append(finished)
            }
        }

        private mutating func endCommand() {
            endWord()
            if !words.isEmpty || ownsHeredoc {
                commands.append(.init(words: words, heredoc: nil, isPiped: nextIsPiped))
                nextIsPiped = false
            }
            words = []
            ownsHeredoc = false
        }

        private mutating func readHeredocBodies() -> Bool {
            for heredoc in pending {
                var lines: [String] = []
                var closed: Bool = false
                while index < characters.count, !closed {
                    let lineEnd: Int = characters[index...].firstIndex(of: "\n") ?? characters.count
                    let line: String = String(characters[index..<lineEnd])
                    closed = line.drop { $0 == "\t" } == heredoc.delimiter
                    if !closed { lines.append(line) }
                    index = min(lineEnd + 1, characters.count)
                }
                guard closed else { return false }
                commands[heredoc.owner].heredoc = lines.joined(separator: "\n")
            }
            pending = []
            return true
        }
    }
}
