import BerthCore

enum StatusState {
    case connecting
    case live(StateSnapshot)
    case disconnected(String)
}
