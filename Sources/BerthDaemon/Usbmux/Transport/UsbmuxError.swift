enum UsbmuxError: Error, Equatable {
    case unavailable
    case timedOut
    case closed
    case malformedReply
    case rejected(code: Int)
}
