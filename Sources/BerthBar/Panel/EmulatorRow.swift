import BerthCore
import SwiftUI

struct EmulatorRow: View {
    let slot: Slot
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            Text(slot.serial).monospaced().frame(width: 105, alignment: .leading)
            Text(slot.model).frame(width: 90, alignment: .leading)
            Text(slot.state.rawValue).foregroundStyle(slot.state.color).frame(width: 70, alignment: .leading)
            Text(slot.lease?.owner.display ?? "—").frame(width: 100, alignment: .leading)
            Text(slot.lease?.label ?? "—").frame(width: 70, alignment: .leading)
            Text(DurationFormat.clock(now.timeIntervalSince(slot.lease?.grantedAt ?? slot.stateSince))).monospacedDigit().frame(width: 55, alignment: .leading)
            Text(slot.lease.map { DurationFormat.remaining($0.expiresAt.timeIntervalSince(now)) } ?? "—")
                .foregroundStyle(.secondary)
                .frame(width: 45, alignment: .leading)
        }
        .lineLimit(1)
        .font(.callout)
    }
}
