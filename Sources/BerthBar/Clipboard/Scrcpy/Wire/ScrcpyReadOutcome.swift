enum ScrcpyReadOutcome: Equatable {
    case bytes([UInt8])
    case timeout
    case closed
}
