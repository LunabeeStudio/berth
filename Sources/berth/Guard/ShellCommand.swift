struct ShellCommand: Equatable {
    var words: [String]
    var heredoc: String?
    var isPiped: Bool
}
