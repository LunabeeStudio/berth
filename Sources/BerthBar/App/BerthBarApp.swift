import SwiftUI

@main
struct BerthBarApp: App {
    @NSApplicationDelegateAdaptor private var delegate: BerthBarDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
