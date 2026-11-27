extension MdnsService {
    static func parse(adbMdnsServices output: String) -> [MdnsService] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields: [Substring] = line.split(whereSeparator: \.isWhitespace)
            guard fields.count == 3, let kind = Kind(serviceType: fields[1]) else { return nil }
            return MdnsService(name: String(fields[0]), kind: kind, address: String(fields[2]))
        }
    }
}

private extension MdnsService.Kind {
    init?(serviceType: Substring) {
        if serviceType.hasPrefix("_adb-tls-pairing._tcp") {
            self = .pairing
        } else if serviceType.hasPrefix("_adb-tls-connect._tcp") {
            self = .connect
        } else {
            return nil
        }
    }
}
