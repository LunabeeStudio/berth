import BerthCore
import SwiftUI

struct EmulatorRow: View {
    let slot: Slot
    let now: Date
    let pool: [PoolEntry]
    let launcher: EmulatorLauncher
    let clipboardActions: ClipboardActions
    let mirror: MirrorController

    var body: some View {
        HStack(spacing: PanelColumns.spacing) {
            Text(slot.serial).monospaced().frame(width: PanelColumns.serial, alignment: .leading)
            Text(slot.displayName).truncationMode(.middle).frame(width: PanelColumns.model, alignment: .leading)
            HStack(spacing: 5) {
                Circle().fill(slot.state.color).frame(width: 8, height: 8)
                Text(slot.state.rawValue)
            }
            .frame(width: PanelColumns.state, alignment: .leading)
            Text(slot.lease?.owner.display ?? "—").frame(width: PanelColumns.owner, alignment: .leading)
            Text(slot.lease?.label ?? "—").frame(width: PanelColumns.label, alignment: .leading)
            Text(DurationFormat.clock(now.timeIntervalSince(slot.lease?.grantedAt ?? slot.stateSince))).monospacedDigit().frame(width: PanelColumns.held, alignment: .leading)
            remaining.frame(width: PanelColumns.remaining, alignment: .leading)
            Color.clear.frame(width: PanelColumns.mirror, height: 1).overlay { mirrorButton }
            Color.clear.frame(width: PanelColumns.clipboard, height: 1).overlay { clipboardButton }
        }
        .lineLimit(1)
        .font(.callout)
    }

    @ViewBuilder
    private var mirrorButton: some View {
        if MirrorEligibility.showsMirrorButton(slot, pool: pool) {
            Button { mirror.open(slot, platform: pool.platform(of: slot.model)) } label: { Image(systemName: "play.display") }
                .buttonStyle(.borderless)
                .help(MirrorEligibility.help(for: slot, pool: pool))
        }
    }

    @ViewBuilder
    private var clipboardButton: some View {
        if ClipboardEligibility.showsCopyButton(slot, pool: pool) {
            ClipboardButton(serial: slot.serial, actions: clipboardActions)
        }
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
