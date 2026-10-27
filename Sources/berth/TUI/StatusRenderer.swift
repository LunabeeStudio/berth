import BerthCore
import Foundation

struct StatusRenderer {
    let snapshot: StateSnapshot
    let now: Date
    let colors: Bool

    private static let slotColumns: [(String, Int)] = [
        ("SERIAL", 15), ("DEVICE", 16), ("STATE", 10), ("OWNER", 18), ("LABEL", 20), ("HELD", 8), ("TTL", 7),
    ]
    private static let queueColumns: [(String, Int)] = [("#", 3), ("OWNER", 18), ("LABEL", 20), ("DEVICE", 16), ("WAITING", 8)]

    func lines(selected: Int?) -> [String] {
        var lines = [
            style("berth", "1") + "  \(snapshot.summary)",
        ]
        if let notice = snapshot.adbNotice(now: now) { lines.append(style(notice, "33")) }
        lines += [
            "",
            style("EMULATORS", "1"),
            "  " + style(row(Self.slotColumns.map { ($0.0, $0.1) }), "2"),
        ]
        if snapshot.slots.isEmpty { lines.append(style("  none running — started on demand by `berth claim`", "2")) }
        for (index, slot) in snapshot.slots.enumerated() {
            lines.append(slotLine(slot, selected: index == selected))
        }
        lines += ["", style("QUEUE", "1"), "  " + style(row(Self.queueColumns.map { ($0.0, $0.1) }), "2")]
        if snapshot.queue.isEmpty { lines.append(style("  empty", "2")) }
        for (index, waiter) in snapshot.queue.enumerated() {
            let cells = [
                String(index + 1),
                waiter.owner.display,
                waiter.label ?? "—",
                waiter.model ?? "any",
                DurationFormat.clock(now.timeIntervalSince(waiter.enqueuedAt)),
            ]
            lines.append("  " + row(zip(cells, Self.queueColumns.map(\.1)).map { ($0, $1) }))
        }
        return lines
    }

    private func remaining(_ lease: Lease?) -> String {
        guard let lease, !lease.manual else { return "—" }
        return DurationFormat.remaining(lease.expiresAt.timeIntervalSince(now))
    }

    private func slotLine(_ slot: Slot, selected: Bool) -> String {
        let lease = slot.lease
        let cells: [String] = [
            slot.serial,
            slot.model,
            slot.state.rawValue,
            lease?.owner.display ?? "—",
            lease?.label ?? "—",
            DurationFormat.clock(now.timeIntervalSince(lease?.grantedAt ?? slot.stateSince)),
            remaining(lease),
        ]
        let widths = Self.slotColumns.map(\.1)
        var rendered = zip(cells, widths).map { Self.pad($0, $1) }
        if !selected { rendered[2] = style(rendered[2], Self.color(for: slot.state)) }
        let line = (selected ? "▶ " : "  ") + rendered.joined(separator: " ")
        return selected ? style(line, "7") : line
    }

    private func row(_ cells: [(String, Int)]) -> String {
        cells.map { Self.pad($0.0, $0.1) }.joined(separator: " ")
    }

    private func style(_ text: String, _ code: String) -> String {
        colors ? "\u{1B}[\(code)m\(text)\u{1B}[0m" : text
    }

    private static func color(for state: SlotState) -> String {
        switch state {
        case .booting: "33"
        case .free: "32"
        case .leased: "36"
        case .resetting: "35"
        case .stopping: "90"
        }
    }

    static func pad(_ text: String, _ width: Int) -> String {
        if text.count > width { return String(text.prefix(width - 1)) + "…" }
        return text.padding(toLength: width, withPad: " ", startingAt: 0)
    }
}
