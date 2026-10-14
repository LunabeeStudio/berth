import BerthCore
import SwiftUI

extension SlotState {
    var color: Color {
        switch self {
        case .booting: .yellow
        case .free: .green
        case .leased: .cyan
        case .resetting: .purple
        case .stopping: .gray
        }
    }
}
