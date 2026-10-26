import Testing

@testable import BerthDaemon

@Suite
struct AdbRestartDetectorTests {
    @Test
    func `first pid is a baseline, not a restart`() {
        var detector: AdbRestartDetector = .init()

        #expect(detector.observe(100) == nil)
    }

    @Test
    func `a different pid is a restart`() {
        var detector: AdbRestartDetector = .init()
        _ = detector.observe(100)

        #expect(detector.observe(200) == .init(old: 100, new: 200))
    }

    @Test
    func `the same pid again is nothing`() {
        var detector: AdbRestartDetector = .init()
        _ = detector.observe(100)

        #expect(detector.observe(100) == nil)
    }

    @Test
    func `missing samples are skipped and a new pid after them counts once`() {
        var detector: AdbRestartDetector = .init()
        _ = detector.observe(100)

        #expect(detector.observe(nil) == nil)
        #expect(detector.observe(200) == .init(old: 100, new: 200))
        #expect(detector.observe(200) == nil)
    }

    @Test
    func `a server that returns with the same pid after a gap is no restart`() {
        var detector: AdbRestartDetector = .init()
        _ = detector.observe(100)
        _ = detector.observe(nil)

        #expect(detector.observe(100) == nil)
    }
}
