struct Wrapper {
    var valueOptions: Set<String> = []
    var skipsLeadingNumber: Bool = false
    var subcommand: String?
    var lookupFlags: Set<String> = []

    func commandWords(after words: ArraySlice<String>) -> ArraySlice<String> {
        if let first = words.first, lookupFlags.contains(first) { return [] }
        var rest: ArraySlice<String> = words
        while let option = rest.first, option.hasPrefix("-") {
            rest = rest.dropFirst(valueOptions.contains(option) ? 2 : 1)
        }
        if skipsLeadingNumber, rest.first?.first?.isNumber == true { rest = rest.dropFirst() }
        if let subcommand, rest.first == subcommand { rest = rest.dropFirst() }
        return rest
    }
}
