import SwiftUI

struct ClipboardButton: View {
    let serial: String
    let actions: ClipboardActions

    var body: some View {
        Button { actions.copy(serial: serial) } label: { Image(systemName: "square.on.square") }
            .buttonStyle(.borderless)
            .help("Copy clipboard to Mac")
    }
}
