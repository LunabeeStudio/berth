import Foundation
import Observation

@Observable
@MainActor
final class ClipboardActions {
    private(set) var caption: String?
    @ObservationIgnored private var reads: [String: Task<Void, Never>] = [:]
    private let clipboard: any DeviceClipboard
    private let pasteboard: any MacPasteboard

    init(
        clipboard: any DeviceClipboard = ScrcpyDeviceClipboard(),
        pasteboard: any MacPasteboard = SystemMacPasteboard()
    ) {
        self.clipboard = clipboard
        self.pasteboard = pasteboard
    }

    @discardableResult
    func copy(serial: String) -> Task<Void, Never> {
        if let running = reads[serial] { return running }
        caption = "Reading clipboard of \(serial)…"
        let read: Task<Void, Never> = Task { [weak self, clipboard] in
            do {
                let text: String? = try await clipboard.text(serial: serial)
                self?.publish(text, from: serial)
            } catch {
                self?.caption = "\(error)"
            }
            self?.reads[serial] = nil
        }
        reads[serial] = read
        return read
    }

    private func publish(_ text: String?, from serial: String) {
        guard let text, !text.isEmpty else {
            caption = "\(serial): clipboard empty"
            return
        }
        pasteboard.replaceContents(with: text)
        caption = "Copied clipboard of \(serial)"
    }
}
