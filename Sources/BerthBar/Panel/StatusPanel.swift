import AppKit
import BerthCore
import SwiftUI

struct StatusPanel: View {
    let model: StatusModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch model.state {
            case .connecting:
                Text("connecting…").font(.headline)
            case let .live(snapshot):
                content(snapshot)
            case let .disconnected(reason):
                Text("daemon not running").font(.headline)
                Text(reason).font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 620)
    }

    @ViewBuilder
    private func content(_ snapshot: StateSnapshot) -> some View {
        Text(snapshot.summary)
            .font(.headline)
        Text("Emulators").font(.subheadline.bold())
        if snapshot.slots.isEmpty {
            Text("none running").foregroundStyle(.secondary)
        }
        ForEach(snapshot.slots) { slot in
            EmulatorRow(slot: slot, now: model.now)
        }
        Text("Queue").font(.subheadline.bold())
        if snapshot.queue.isEmpty {
            Text("empty").foregroundStyle(.secondary)
        }
        ForEach(Array(snapshot.queue.enumerated()), id: \.element.id) { index, waiter in
            QueueRow(position: index + 1, waiter: waiter, now: model.now)
        }
    }
}
