import Foundation
import Synchronization
import Testing

@testable import BerthCore

@Suite
struct ExecutableReplacerTests {
    private final class World: Sendable {
        let alive: Mutex<Set<Int32>>
        let signaled: Mutex<[Int32]> = .init([])
        let sleeps: Mutex<Int> = .init(0)
        let stubborn: Set<Int32>

        init(alive: Set<Int32>, stubborn: Set<Int32> = []) {
            self.alive = .init(alive)
            self.stubborn = stubborn
        }

        func replacer(running: [String: [Int32]]) -> ExecutableReplacer {
            .init(
                pids: { running[$0] ?? [] },
                terminate: { pid in
                    self.signaled.withLock { $0.append(pid) }
                    if !self.stubborn.contains(pid) { _ = self.alive.withLock { $0.remove(pid) } }
                },
                isAlive: { pid in self.alive.withLock { $0.contains(pid) } },
                sleep: { _ in self.sleeps.withLock { $0 += 1 } }
            )
        }
    }

    @Test
    func `same path pids get SIGTERM and other paths are untouched`() async {
        let world: World = .init(alive: [10, 11, 20])
        let replacer: ExecutableReplacer = world.replacer(running: ["/a/berth-bar": [10, 11], "/b/berth-bar": [20]])

        let survivors: [Int32] = await replacer.stop(executable: "/a/berth-bar")

        #expect(survivors.isEmpty)
        #expect(world.signaled.withLock { $0 } == [10, 11])
        #expect(world.alive.withLock { $0 } == [20])
    }

    @Test
    func `nothing running returns at once`() async {
        let world: World = .init(alive: [])
        let survivors: [Int32] = await world.replacer(running: [:]).stop(executable: "/a/berth-bar")
        #expect(survivors.isEmpty)
        #expect(world.sleeps.withLock { $0 } == 0)
    }

    @Test
    func `a pid still alive after the timeout is returned`() async {
        let world: World = .init(alive: [10, 11], stubborn: [11])
        let replacer: ExecutableReplacer = world.replacer(running: ["/a/berth-bar": [10, 11]])

        let survivors: [Int32] = await replacer.stop(executable: "/a/berth-bar", timeout: .seconds(1), pollInterval: .milliseconds(100))

        #expect(survivors == [11])
        #expect(world.sleeps.withLock { $0 } == 10)
    }

    @Test
    func `pids lists nothing for a path no process runs`() {
        #expect(ProcessInspector.pids(running: "/nonexistent/berth-bar").isEmpty)
    }
}
