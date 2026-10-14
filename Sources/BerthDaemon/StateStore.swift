import BerthCore
import Foundation

public struct StateStore: Sendable {
    let url: URL

    public init(url: URL) {
        self.url = url
    }

    func load() -> [Slot] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? Wire.decoder().decode([Slot].self, from: data)) ?? []
    }

    func save(_ slots: [Slot]) {
        do {
            try Wire.encoder(pretty: true).encode(slots).write(to: url, options: .atomic)
        } catch {
            Log.info("cannot persist state: \(error)")
        }
    }
}
