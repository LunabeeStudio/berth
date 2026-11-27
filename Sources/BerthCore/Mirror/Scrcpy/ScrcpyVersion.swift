public enum ScrcpyVersion {
    public static func parse(versionOutput: String) -> String? {
        let words: [Substring] = versionOutput.split(whereSeparator: \.isNewline).first?.split(separator: " ") ?? []
        guard words.count >= 2, words[0] == "scrcpy" else { return nil }
        return String(words[1])
    }
}
