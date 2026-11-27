enum WifiAddress {
    static func parse(ipAddr output: String) -> String? {
        output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.hasPrefix("inet ") }
            .flatMap { $0.split(whereSeparator: \.isWhitespace).dropFirst().first }
            .map { String($0.prefix { $0 != "/" }) }
    }
}
