import BerthCore

struct AVDMenuItems: Equatable {
    struct LaunchItem: Equatable {
        let name: String
        let title: String
        let inPool: Bool
    }

    let launch: [LaunchItem]
    let prepare: [String]

    init(avds: [AVD], pool: [PoolEntry]) {
        let poolNames: Set<String> = Set(pool.filter { $0.platform == .android }.map(\.name))
        let sorted: [AVD] = avds.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        launch = sorted.map { LaunchItem(name: $0.name, title: $0.prepared ? $0.name : "\($0.name) (not prepared)", inPool: poolNames.contains($0.name)) }
        prepare = sorted.filter { !($0.prepared && poolNames.contains($0.name)) }.map(\.name)
    }
}
