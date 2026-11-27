import Foundation

protocol ScrcpyControlChannel {
    func write(_ bytes: [UInt8]) -> Bool
    func read(until deadline: ContinuousClock.Instant) -> ScrcpyReadOutcome
}
