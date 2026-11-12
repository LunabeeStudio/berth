import BerthCore
import Observation

@Observable
@MainActor
final class AVDList {
    private(set) var avds: [AVD] = []
    @ObservationIgnored private let load: @Sendable () async -> [AVD]

    init(load: @escaping @Sendable () async -> [AVD] = { await AVDCatalog.avds(config: (try? Config.load()) ?? Config()) }) {
        self.load = load
    }

    func refresh() async {
        avds = await load()
    }
}
