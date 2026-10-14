import BerthCore
import Foundation
import Observation

@Observable
@MainActor
final class StatusModel {
    private(set) var state: StatusState = .connecting
    private(set) var now: Date = .init()

    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init() {
        tasks.append(Task { [weak self] in
            for await update in DaemonWatch.updates(autoSpawn: false) {
                self?.apply(update)
            }
        })
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.now = Date()
            }
        })
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }

    private func apply(_ update: WatchUpdate) {
        switch update {
        case let .snapshot(snapshot): state = .live(snapshot)
        case let .disconnected(reason): state = .disconnected(reason)
        }
    }
}
