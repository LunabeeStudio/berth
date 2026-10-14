import AppKit
import SwiftUI

@main
struct BerthBarApp: App {
    @State private var model: StatusModel = .init()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            StatusPanel(model: model)
        } label: {
            MenuBarLabelView(state: model.state)
        }
        .menuBarExtraStyle(.window)
    }
}
