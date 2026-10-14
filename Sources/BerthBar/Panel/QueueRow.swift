import BerthCore
import SwiftUI

struct QueueRow: View {
    let position: Int
    let waiter: WaiterInfo
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            Text("\(position)").frame(width: 20, alignment: .leading)
            Text(waiter.owner.display).frame(width: 130, alignment: .leading)
            Text(waiter.label ?? "—").frame(width: 110, alignment: .leading)
            Text(waiter.model ?? "any").frame(width: 100, alignment: .leading)
            Text(DurationFormat.clock(now.timeIntervalSince(waiter.enqueuedAt))).monospacedDigit().frame(width: 55, alignment: .leading)
        }
        .lineLimit(1)
        .font(.callout)
    }
}
