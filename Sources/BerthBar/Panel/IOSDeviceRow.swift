import BerthCore
import SwiftUI

struct IOSDeviceRow: View {
    let device: IOSDevice

    var body: some View {
        HStack(spacing: PanelColumns.spacing) {
            Text(device.name ?? "—").frame(width: PanelColumns.serial, alignment: .leading).help(device.udid)
            Text(device.productType ?? "—").frame(width: PanelColumns.model, alignment: .leading)
            Text(detail).frame(width: PanelColumns.detailSpan - PanelColumns.kill - PanelColumns.spacing, alignment: .leading)
            Color.clear.frame(width: PanelColumns.kill, height: 1)
            Color.clear.frame(width: PanelColumns.mirror, height: 1)
        }
        .lineLimit(1)
        .font(.callout)
    }

    private var detail: String {
        let version: String = device.osVersion.map { "iOS \($0)" } ?? "—"
        return "\(version) · \(device.trusted ? "trusted" : "not trusted")"
    }
}
