@MainActor
final class PairWindowController {
    private let makeFlow: () -> PairFlow
    private let makeWindow: (PairFlow, @escaping () -> Void) -> any PairWindowing
    private var open: (flow: PairFlow, window: any PairWindowing)?

    init(
        makeFlow: @escaping () -> PairFlow = { PairFlow() },
        makeWindow: @escaping (PairFlow, @escaping () -> Void) -> any PairWindowing = { AppKitPairWindow(flow: $0, onClose: $1) }
    ) {
        self.makeFlow = makeFlow
        self.makeWindow = makeWindow
    }

    func show() {
        if let open {
            open.window.bringToFront()
            return
        }
        let flow: PairFlow = makeFlow()
        let window: any PairWindowing = makeWindow(flow) { [weak self] in self?.close() }
        open = (flow, window)
        window.bringToFront()
        flow.start()
    }

    private func close() {
        open?.flow.cancel()
        open = nil
    }
}
