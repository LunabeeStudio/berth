import BerthCore
import SwiftUI

struct DeviceRow: View {
    let device: PhysicalDevice
    let mirror: MirrorController

    var body: some View {
        HStack(spacing: PanelColumns.spacing) {
            Text(device.serial).monospaced().frame(width: PanelColumns.serial, alignment: .leading).help(device.serial)
            Text(device.model ?? "—").frame(width: PanelColumns.model, alignment: .leading)
            Text(device.state.word).frame(width: PanelColumns.detailSpan, alignment: .leading)
            mirrorButton.frame(width: PanelColumns.mirror)
        }
        .lineLimit(1)
        .font(.callout)
    }

    @ViewBuilder
    private var mirrorButton: some View {
        if MirrorEligibility.showsMirrorButton(device) {
            Button { mirror.open(device) } label: { Image(systemName: "play.display") }
                .buttonStyle(.borderless)
                .help("Mirror")
        }
    }
}
