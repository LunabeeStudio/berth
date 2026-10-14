import Testing

@testable import BerthCore

@Suite
struct DurationFormatTests {
    @Test
    func `clock shows minutes and seconds under an hour`() {
        #expect(DurationFormat.clock(65) == "1:05")
        #expect(DurationFormat.clock(0) == "0:00")
        #expect(DurationFormat.clock(3599) == "59:59")
    }

    @Test
    func `clock shows hours from one hour`() {
        #expect(DurationFormat.clock(3600) == "1:00:00")
        #expect(DurationFormat.clock(3725) == "1:02:05")
    }

    @Test
    func `clock clamps negative intervals to zero`() {
        #expect(DurationFormat.clock(-30) == "0:00")
    }

    @Test
    func `remaining reports expired at or below zero`() {
        #expect(DurationFormat.remaining(0) == "expired")
        #expect(DurationFormat.remaining(-5) == "expired")
    }

    @Test
    func `remaining shows whole minutes under an hour`() {
        #expect(DurationFormat.remaining(30) == "0m")
        #expect(DurationFormat.remaining(15 * 60 + 59) == "15m")
    }

    @Test
    func `remaining shows hours and padded minutes from an hour`() {
        #expect(DurationFormat.remaining(3600) == "1h00")
        #expect(DurationFormat.remaining(3600 + 5 * 60) == "1h05")
        #expect(DurationFormat.remaining(2 * 3600 + 30 * 60) == "2h30")
    }
}
