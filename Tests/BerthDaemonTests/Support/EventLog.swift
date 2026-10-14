import BerthCore
import Synchronization

final class EventLog: Sendable {
    let events = Mutex<[Event]>([])
}
