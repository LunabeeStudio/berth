import Testing

@testable import BerthBar

@MainActor
@Suite
struct PairWindowControllerTests {
    private final class FakeWindow: PairWindowing {
        let onClose: () -> Void
        private(set) var frontCount: Int = 0

        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
        }

        func bringToFront() { frontCount += 1 }
    }

    private final class Recorder {
        var flows: [PairFlow] = []
        var windows: [FakeWindow] = []
    }

    private func controller(_ adb: FakeWifiAdb, _ recorder: Recorder) -> PairWindowController {
        .init(
            makeFlow: {
                let flow: PairFlow = .init(adb: adb, clock: FakePairClock(blocking: true))
                recorder.flows.append(flow)
                return flow
            },
            makeWindow: { _, onClose in
                let window: FakeWindow = .init(onClose: onClose)
                recorder.windows.append(window)
                return window
            }
        )
    }

    @Test
    func `a second open brings the same window to the front without a new flow`() {
        let recorder: Recorder = .init()
        let controller: PairWindowController = controller(.init(), recorder)

        controller.show()
        controller.show()

        #expect(recorder.flows.count == 1)
        #expect(recorder.windows.count == 1)
        #expect(recorder.windows[0].frontCount == 2)
        recorder.flows[0].cancel()
    }

    @Test
    func `closing the window stops the polling and the next open is a fresh flow`() async throws {
        let adb: FakeWifiAdb = .init()
        let recorder: Recorder = .init()
        let controller: PairWindowController = controller(adb, recorder)
        controller.show()
        while !adb.calls.contains("mdns") { try await Task.sleep(for: .milliseconds(5)) }

        recorder.windows[0].onClose()
        try await Task.sleep(for: .milliseconds(100))
        let callsAfterClose: [String] = adb.calls
        try await Task.sleep(for: .milliseconds(100))

        #expect(adb.calls == callsAfterClose)
        controller.show()
        #expect(recorder.flows.count == 2)
        #expect(recorder.windows.count == 2)
        recorder.flows[1].cancel()
    }
}
