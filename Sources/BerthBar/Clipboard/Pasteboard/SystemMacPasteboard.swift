import AppKit

struct SystemMacPasteboard: MacPasteboard {
    func replaceContents(with text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
