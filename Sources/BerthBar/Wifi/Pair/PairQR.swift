struct PairQR: Sendable, Equatable {
    let name: String
    let password: String

    var payload: String { "WIFI:T:ADB;S:\(name);P:\(password);;" }

    static func random() -> PairQR {
        PairQR(name: "berth-\(randomToken(length: 8))", password: randomToken(length: 12))
    }

    private static func randomToken(length: Int) -> String {
        let alphabet: [Character] = .init("abcdefghijkmnpqrstuvwxyz23456789")
        return String((0 ..< length).compactMap { _ in alphabet.randomElement() })
    }
}
