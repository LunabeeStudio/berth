public enum WatchUpdate: Sendable {
    case snapshot(StateSnapshot)
    case disconnected(String)
}
