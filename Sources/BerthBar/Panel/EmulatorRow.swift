import BerthCore
import SwiftUI

struct EmulatorRow: View {
    let slot: Slot
    let now: Date
    let launcher: EmulatorLauncher

    var body: some View {
        HStack(spacing: 8) {
            Text(slot.serial).monospaced().frame(width: 105, alignment: .leading)
            Text(slot.model).frame(width: 90, alignment: .leading)
            HStack(spacing: 5) {
                Circle().fill(slot.state.color).frame(width: 8, height: 8)
                Text(slot.state.rawValue)
            }
            .frame(width: 70, alignment: .leading)
            Text(slot.lease?.owner.display ?? "—").frame(width: 95, alignment: .leading)
            Text(slot.lease?.label ?? "—").frame(width: 70, alignment: .leading)
            Text(DurationFormat.clock(now.timeIntervalSince(slot.lease?.grantedAt ?? slot.stateSince))).monospacedDigit().frame(width: 55, alignment: .leading)
            remaining.frame(width: 60, alignment: .leading)
        }
        .lineLimit(1)
        .font(.callout)
    }

    @ViewBuilder
    private var remaining: some View {
        if slot.isManuallyLeased {
            Button("Release") { launcher.release(serial: slot.serial) }
                .controlSize(.small)
        } else {
            Text(slot.lease.map { DurationFormat.remaining($0.expiresAt.timeIntervalSince(now)) } ?? "—")
                .foregroundStyle(.secondary)
        }
    }
}
