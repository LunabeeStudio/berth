/// Numeric `X.Y.Z` version, optionally prefixed by `v`.
public struct SemanticVersion: Comparable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public var description: String { "\(major).\(minor).\(patch)" }

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// - Returns: `nil` unless the text is exactly three non-negative integers separated by dots (`dev` included).
    public init?(_ text: String) {
        let trimmed: Substring = text.hasPrefix("v") ? text.dropFirst() : Substring(text)
        let parts: [Int?] = trimmed.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard
            parts.count == 3,
            let major = parts[0], let minor = parts[1], let patch = parts[2],
            major >= 0, minor >= 0, patch >= 0
        else {
            return nil
        }
        self.init(major: major, minor: minor, patch: patch)
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
