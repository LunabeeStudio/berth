import SwiftUI

struct MenuBarLabelView: View {
    let state: StatusState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            if let text = MenuBarLabel.text(for: state) { Text(text) }
        }
    }

    private var symbol: String {
        if case .live = state { "iphone" } else { "iphone.slash" }
    }
}
