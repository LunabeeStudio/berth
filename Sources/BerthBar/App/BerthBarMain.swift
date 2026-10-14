import AppKit

@main
enum BerthBarMain {
    @MainActor
    static func main() {
        let app: NSApplication = .shared
        let delegate: BerthBarDelegate = .init()
        app.delegate = delegate
        app.run()
    }
}
