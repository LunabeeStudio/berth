import SwiftUI

struct ClipboardButton: View {
    let serial: String
    let actions: ClipboardActions

    var body: some View {
        Button { actions.copy(serial: serial) } label: { Image(systemName: "doc.on.clipboard") }
            .buttonStyle(.borderless)
            .help("Copy clipboard to Mac")
    }
}
