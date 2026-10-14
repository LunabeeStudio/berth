import ArgumentParser
import BerthCore
import Foundation

struct Top: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Live view of emulators, leases and the queue.")

    enum UIEvent: Sendable {
        case watch(WatchUpdate)
        case actionFailed(String)
        case key(Key)
        case tick
    }

    func run() async throws {
        guard isatty(STDIN_FILENO) == 1, isatty(STDOUT_FILENO) == 1 else {
            throw ValidationError("`berth top` needs a terminal; use `berth status` instead")
        }
        let (events, sink) = AsyncStream.makeStream(of: UIEvent.self)

        let watcher = Task {
            for await update in DaemonWatch.updates(autoSpawn: true) {
                sink.yield(.watch(update))
            }
        }
        let keyboard = Task {
            for await key in Terminal.keys() { sink.yield(.key(key)) }
        }
        let ticker = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                sink.yield(.tick)
            }
        }
        let resize = DispatchSource.makeSignalSource(signal: SIGWINCH)
        signal(SIGWINCH, SIG_IGN)
        resize.setEventHandler { sink.yield(.tick) }
        resize.resume()

        let terminal = Terminal()
        terminal.enter()
        defer {
            terminal.restore()
            resize.cancel()
            watcher.cancel()
            keyboard.cancel()
            ticker.cancel()
        }

        var snapshot: StateSnapshot?
        var problem: String? = "connecting…"
        var selected = 0
        var notice: String?

        loop: for await event in events {
            switch event {
            case let .watch(.snapshot(next)):
                snapshot = next
                problem = nil
            case let .watch(.disconnected(reason)):
                problem = reason
            case let .actionFailed(reason):
                problem = reason
            case .tick:
                break
            case let .key(key):
                let slots = snapshot?.slots ?? []
                switch key {
                case .quit:
                    break loop
                case .up:
                    selected = max(0, selected - 1)
                case .down:
                    selected = min(max(0, slots.count - 1), selected + 1)
                case .release, .kill:
                    guard slots.indices.contains(selected) else { break }
                    let serial = slots[selected].serial
                    let request: Request = key == .release ? .release(target: serial) : .stop(target: serial)
                    notice = key == .release ? "releasing \(serial)…" : "stopping \(serial)…"
                    Task {
                        do { try await DaemonClient.call(request, autoSpawn: false) } catch { sink.yield(.actionFailed("\(error)")) }
                    }
                case .other:
                    break
                }
            }
            selected = min(selected, max(0, (snapshot?.slots.count ?? 1) - 1))
            render(snapshot: snapshot, problem: problem, notice: notice, selected: selected)
        }
    }

    private func render(snapshot: StateSnapshot?, problem: String?, notice: String?, selected: Int) {
        let size = Terminal.size
        var lines: [String] = []
        if let snapshot {
            lines = StatusRenderer(snapshot: snapshot, now: Date(), colors: true).lines(selected: selected)
        }
        if let problem { lines += ["", "\u{1B}[31m\(problem)\u{1B}[0m"] }
        if let notice { lines += ["", "\u{1B}[2m\(notice)\u{1B}[0m"] }
        let footer = "\u{1B}[2m↑↓ select   r release   x stop emulator   q quit\u{1B}[0m"
        lines = Array(lines.prefix(max(0, size.rows - 2)))
        let body = lines.map { $0 + "\u{1B}[K" }.joined(separator: "\r\n")
        Terminal.write("\u{1B}[H" + body + "\u{1B}[J" + "\u{1B}[\(size.rows);1H" + footer)
    }
}
