import BerthCore
import Foundation

public actor Broker {
    struct Waiter {
        let id: String
        let conn: UUID
        let request: ClaimRequest
        let enqueuedAt: Date
        let sink: AsyncStream<Event>.Continuation
        var lastPosition: Int?
    }

    static let missedTicksBeforeVanished = 3
    static let bootFailuresBeforeBroken = 3
    static let brokenCooldown: TimeInterval = 600

    private let config: Config
    private let backend: any DeviceBackend
    private let store: StateStore?
    private let now: @Sendable () -> Date
    private let ownerAlive: @Sendable (Owner) -> Bool

    private var slots: [String: Slot] = [:]
    private var waiters: [Waiter] = []
    private var watchers: [UUID: AsyncStream<Event>.Continuation] = [:]
    private var unacknowledged: [UUID: Set<String>] = [:]
    private var externalSerials: Set<String> = []
    private var missedTicks: [String: Int] = [:]
    private var bootFailures: [String: Int] = [:]
    private var brokenUntil: [String: Date] = [:]
    private var generationCounter = 0

    public init(
        config: Config,
        backend: any DeviceBackend,
        store: StateStore? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        ownerAlive: @escaping @Sendable (Owner) -> Bool = ProcessInspector.isAlive
    ) {
        self.config = config
        self.backend = backend
        self.store = store
        self.now = now
        self.ownerAlive = ownerAlive
    }

    // region Requests

    public func claim(_ request: ClaimRequest, conn: UUID, sink: AsyncStream<Event>.Continuation) {
        let platform = request.resolvedPlatform
        let models = config.models(for: platform)
        guard !models.isEmpty else {
            sink.yield(.failure("the pool has no \(platform) entries: add them to \(Paths.config.path) and run `berth daemon stop`"))
            return
        }
        if let model = request.model {
            guard models.contains(model) else {
                sink.yield(.failure("\(platform.deviceKind) '\(model)' is not in the pool (\(models.joined(separator: ", ")))"))
                return
            }
            if let reason = backend.unavailableReason(model: model) {
                sink.yield(.failure("\(model) is unavailable: \(reason)"))
                return
            }
            if isBroken(model) {
                sink.yield(.failure("\(platform.deviceKind) '\(model)' failed to boot repeatedly; see \(Paths.logs.path)"))
                return
            }
        }
        let reasons = models.compactMap { backend.unavailableReason(model: $0) }
        if request.model == nil, let reason = reasons.first, reasons.count == models.count {
            sink.yield(.failure("no \(platform) device is available: \(reason)"))
            return
        }
        waiters.append(Waiter(id: Self.shortID(), conn: conn, request: request, enqueuedAt: now(), sink: sink))
        schedule()
    }

    public func acknowledge(lease: String, conn: UUID) {
        unacknowledged[conn]?.remove(lease)
        guard let serial = slots.values.first(where: { $0.lease?.id == lease })?.serial else { return }
        slots[serial]?.lease?.acknowledged = true
        changed()
    }

    public func release(_ target: String) -> Event {
        guard let slot = resolve(target) else { return .failure("no emulator matches '\(target)'") }
        guard slot.state == .leased, let lease = slot.lease else { return .failure("\(slot.serial) is not leased (\(slot.state.rawValue))") }
        Log.info("\(slot.serial): released by \(lease.owner.display)")
        beginReset(slot.serial)
        return .ok("released \(slot.serial)")
    }

    public func renew(_ target: String, ttl: Int?) -> Event {
        guard let slot = resolve(target), slot.state == .leased, slot.lease != nil else { return .failure("no leased emulator matches '\(target)'") }
        let expiry = now().addingTimeInterval(TimeInterval(ttl ?? config.defaultTTLSeconds))
        slots[slot.serial]?.lease?.expiresAt = expiry
        changed()
        return .ok("\(slot.serial) leased until \(expiry.formatted(date: .omitted, time: .shortened))")
    }

    public func stop(_ target: String) -> Event {
        guard let slot = resolve(target) else { return .failure("no emulator matches '\(target)'") }
        beginStop(slot.serial, reason: "stopped on request")
        return .ok("stopping \(slot.serial)")
    }

    public func stopAll() -> Event {
        for waiter in waiters { waiter.sink.yield(.failure("all emulators were stopped by `berth stop-all`")) }
        waiters.removeAll()
        let serials = slots.keys.sorted { $0.numericallyPrecedes($1) }
        for serial in serials { beginStop(serial, reason: "stop-all") }
        changed()
        return .ok(serials.isEmpty ? "nothing running" : "stopping \(serials.joined(separator: ", "))")
    }

    public func watch(conn: UUID, sink: AsyncStream<Event>.Continuation) {
        watchers[conn] = sink
        sink.yield(.state(snapshot()))
    }

    /// A claim whose client disconnected before acknowledging the grant goes back to the pool.
    public func connectionClosed(_ conn: UUID) {
        watchers[conn] = nil
        let before = waiters.count
        waiters.removeAll { $0.conn == conn }
        var dirty = waiters.count != before
        for leaseID in unacknowledged.removeValue(forKey: conn) ?? [] {
            guard let slot = slots.values.first(where: { $0.lease?.id == leaseID }), slot.lease?.acknowledged == false else { continue }
            Log.info("\(slot.serial): client left before acknowledging the grant")
            beginReset(slot.serial)
            dirty = true
        }
        if dirty { schedule() }
    }

    public func snapshot() -> StateSnapshot {
        StateSnapshot(
            slots: slots.values.sorted { $0.serial.numericallyPrecedes($1.serial) },
            queue: waiters.map {
                WaiterInfo(id: $0.id, owner: $0.request.owner, label: $0.request.label, model: $0.request.model, enqueuedAt: $0.enqueuedAt)
            },
            maxRunning: config.maxRunning,
            pool: config.pool,
            generatedAt: now()
        )
    }

    // endregion

    // region Housekeeping

    public func restore() async {
        let saved = store?.load() ?? []
        let live = await backend.liveSerials() ?? []
        externalSerials = live
        for var slot in saved where live.contains(slot.serial) {
            slot.generation = nextGeneration()
            slot.lease?.acknowledged = true
            slots[slot.serial] = slot
            Log.info("\(slot.serial): adopted from previous daemon (\(slot.state.rawValue))")
            if slot.state != .free && slot.state != .leased {
                beginStop(slot.serial, reason: "was \(slot.state.rawValue) when the daemon stopped")
            }
        }
        changed()
    }

    public func reap() async {
        let live = await backend.liveSerials()
        let current = now()

        if let live {
            externalSerials = live
            for slot in slots.values where slot.state == .free || slot.state == .leased {
                if live.contains(slot.serial) {
                    missedTicks[slot.serial] = nil
                    continue
                }
                let misses = (missedTicks[slot.serial] ?? 0) + 1
                missedTicks[slot.serial] = misses
                let processGone = slot.pid.map { !backend.isProcessAlive($0) } ?? false
                if processGone || misses >= Self.missedTicksBeforeVanished {
                    beginStop(slot.serial, reason: "vanished from the device list")
                }
            }
        }

        for slot in slots.values where slot.state == .leased {
            guard let lease = slot.lease else { continue }
            if !ownerAlive(lease.owner) {
                Log.info("\(slot.serial): owner \(lease.owner.display) is gone, reclaiming")
                beginReset(slot.serial)
            } else if lease.expiresAt <= current {
                Log.info("\(slot.serial): lease of \(lease.owner.display) expired, reclaiming")
                beginReset(slot.serial)
            }
        }

        waiters.removeAll { waiter in
            guard !ownerAlive(waiter.request.owner) else { return false }
            waiter.sink.yield(.failure("owner process is gone"))
            return true
        }

        let idleLimit = TimeInterval(config.idleShutdownSeconds)
        for slot in slots.values where slot.state == .free && current.timeIntervalSince(slot.stateSince) >= idleLimit {
            beginStop(slot.serial, reason: "idle")
        }

        schedule()
    }

    // endregion

    // region Scheduling

    private func schedule() {
        grantFreeSlots()
        provisionForWaiters()
        publishPositions()
        changed()
    }

    private func grantFreeSlots() {
        var index = 0
        while index < waiters.count {
            if let slot = freeSlot(for: waiters[index].request) {
                grant(slot.serial, to: waiters.remove(at: index))
            } else {
                index += 1
            }
        }
    }

    /// Each waiter takes one upcoming (booting/resetting) slot, else a new boot, else evicts an idle slot of another model.
    private func provisionForWaiters() {
        var upcoming = slots.values.filter { $0.state == .booting || $0.state == .resetting }
        var pendingStops = slots.values.filter { $0.state == .stopping }.count

        for waiter in waiters {
            if let index = upcoming.firstIndex(where: { matches($0, waiter.request) }) {
                upcoming.remove(at: index)
                continue
            }
            let candidates = candidateModels(for: waiter.request)
            if slots.count < config.maxRunning, let model = candidates.first(where: hasInstanceRoom) {
                if boot(model) { continue }
            }
            guard candidates.contains(where: hasInstanceRoom) else { continue }
            if pendingStops > 0 {
                pendingStops -= 1
                continue
            }
            if let victim = slots.values.filter({ $0.state == .free }).min(by: { $0.stateSince < $1.stateSince }) {
                beginStop(victim.serial, reason: "evicted to boot a different model")
            }
        }
    }

    private func publishPositions() {
        for index in waiters.indices where waiters[index].lastPosition != index + 1 {
            waiters[index].lastPosition = index + 1
            waiters[index].sink.yield(.queued(position: index + 1))
        }
    }

    private func freeSlot(for request: ClaimRequest) -> Slot? {
        slots.values
            .filter { $0.state == .free && matches($0, request) }
            .min { $0.stateSince < $1.stateSince }
    }

    private func matches(_ slot: Slot, _ request: ClaimRequest) -> Bool {
        guard config.platform(of: slot.model) == request.resolvedPlatform else { return false }
        return request.model == nil || request.model == slot.model
    }

    private func candidateModels(for request: ClaimRequest) -> [String] {
        let models = request.model.map { [$0] } ?? config.models(for: request.resolvedPlatform)
        return models.filter { !isBroken($0) && backend.unavailableReason(model: $0) == nil }
    }

    private func hasInstanceRoom(_ model: String) -> Bool {
        let limit = config.entry(for: model)?.maxInstances ?? 1
        return slots.values.filter { $0.model == model }.count < limit
    }

    private func isBroken(_ model: String) -> Bool {
        guard let until = brokenUntil[model] else { return false }
        if until > now() { return true }
        brokenUntil[model] = nil
        return false
    }

    private func grant(_ serial: String, to waiter: Waiter) {
        let current = now()
        let ttl = TimeInterval(waiter.request.ttl ?? config.defaultTTLSeconds)
        let lease = Lease(
            id: Self.shortID(),
            owner: waiter.request.owner,
            label: waiter.request.label,
            grantedAt: current,
            expiresAt: current.addingTimeInterval(ttl),
            acknowledged: false
        )
        slots[serial]?.state = .leased
        slots[serial]?.stateSince = current
        slots[serial]?.lease = lease
        unacknowledged[waiter.conn, default: []].insert(lease.id)
        Log.info("\(serial): leased to \(lease.owner.display)\(lease.label.map { " (\($0))" } ?? "")")
        if let slot = slots[serial] {
            waiter.sink.yield(.granted(Grant(serial: serial, model: slot.model, leaseID: lease.id, expiresAt: lease.expiresAt)))
        }
    }

    // endregion

    // region Slot lifecycle

    private func boot(_ model: String) -> Bool {
        let taken = Set(slots.keys).union(externalSerials)
        guard let serial = backend.nextSerial(model: model, taken: taken) else { return false }
        let generation = nextGeneration()
        slots[serial] = Slot(serial: serial, model: model, pid: nil, state: .booting, stateSince: now(), generation: generation)
        Log.info("\(serial): booting \(model)")
        let backend = backend
        Task {
            do {
                let pid = try await backend.launch(serial: serial, model: model)
                self.recordPID(pid, serial: serial, generation: generation)
                try await backend.waitReady(serial: serial, pid: pid)
                self.bootFinished(serial: serial, model: model, generation: generation, error: nil)
            } catch {
                self.bootFinished(serial: serial, model: model, generation: generation, error: error)
            }
        }
        return true
    }

    private func recordPID(_ pid: Int32?, serial: String, generation: Int) {
        guard slots[serial]?.generation == generation else { return }
        slots[serial]?.pid = pid
        changed()
    }

    private func bootFinished(serial: String, model: String, generation: Int, error: Error?) {
        guard let slot = slots[serial], slot.generation == generation, slot.state == .booting else {
            if error == nil { discardOrphan(serial: serial, model: model, generation: generation, pid: slots[serial]?.pid) }
            return
        }
        if let error {
            Log.info("\(serial): boot failed: \(error)")
            let failures = (bootFailures[slot.model] ?? 0) + 1
            bootFailures[slot.model] = failures
            if failures >= Self.bootFailuresBeforeBroken {
                markBroken(slot.model)
            }
            beginStop(serial, reason: "boot failed")
            return
        }
        bootFailures[slot.model] = 0
        Log.info("\(serial): ready")
        slots[serial]?.state = .free
        slots[serial]?.stateSince = now()
        schedule()
    }

    private func markBroken(_ model: String) {
        bootFailures[model] = 0
        brokenUntil[model] = now().addingTimeInterval(Self.brokenCooldown)
        let brokenPlatform = config.platform(of: model)
        let allBroken = config.models(for: brokenPlatform).allSatisfy { isBroken($0) || backend.unavailableReason(model: $0) != nil }
        waiters.removeAll { waiter in
            let anyDevice = waiter.request.model == nil && waiter.request.resolvedPlatform == brokenPlatform
            guard waiter.request.model == model || (anyDevice && allBroken) else { return false }
            waiter.sink.yield(.failure("\(brokenPlatform.deviceKind) '\(model)' failed to boot \(Self.bootFailuresBeforeBroken) times; see \(Paths.logs.path)"))
            return true
        }
    }

    private func beginReset(_ serial: String) {
        guard let slot = slots[serial] else { return }
        slots[serial]?.state = .resetting
        slots[serial]?.stateSince = now()
        slots[serial]?.lease = nil
        let backend = backend
        let generation = slot.generation
        Task {
            do {
                let pid = try await backend.reset(serial: serial, model: slot.model, pid: slot.pid)
                self.resetFinished(serial: serial, model: slot.model, generation: generation, pid: pid, error: nil)
            } catch {
                self.resetFinished(serial: serial, model: slot.model, generation: generation, pid: nil, error: error)
            }
        }
        schedule()
    }

    private func resetFinished(serial: String, model: String, generation: Int, pid: Int32?, error: Error?) {
        guard slots[serial]?.generation == generation, slots[serial]?.state == .resetting else {
            if error == nil { discardOrphan(serial: serial, model: model, generation: generation, pid: pid) }
            return
        }
        if let error {
            beginStop(serial, reason: "reset failed (\(error))")
            return
        }
        Log.info("\(serial): ready after reset")
        slots[serial]?.pid = pid
        slots[serial]?.state = .free
        slots[serial]?.stateSince = now()
        schedule()
    }

    /// A boot or reset finishing after its slot was stopped has brought the device back up; a newer slot owning the serial is left alone.
    private func discardOrphan(serial: String, model: String, generation: Int, pid: Int32?) {
        let current = slots[serial]
        guard current == nil || (current?.generation == generation && current?.state == .stopping) else { return }
        Log.info("\(serial): stopping (device came up after its slot was stopped)")
        let generation = nextGeneration()
        slots[serial] = Slot(serial: serial, model: model, pid: pid, state: .stopping, stateSince: now(), generation: generation)
        startShutdown(serial: serial, generation: generation, pid: pid)
        changed()
    }

    private func startShutdown(serial: String, generation: Int, pid: Int32?) {
        let backend = backend
        Task {
            await backend.shutdown(serial: serial, pid: pid)
            self.removeSlot(serial: serial, generation: generation)
        }
    }

    private func beginStop(_ serial: String, reason: String) {
        guard let slot = slots[serial], slot.state != .stopping else { return }
        Log.info("\(serial): stopping (\(reason))")
        slots[serial]?.state = .stopping
        slots[serial]?.stateSince = now()
        slots[serial]?.lease = nil
        missedTicks[serial] = nil
        startShutdown(serial: serial, generation: slot.generation, pid: slot.pid)
        changed()
    }

    private func removeSlot(serial: String, generation: Int) {
        guard slots[serial]?.generation == generation else { return }
        slots[serial] = nil
        Log.info("\(serial): stopped")
        schedule()
    }

    // endregion

    private func resolve(_ target: String) -> Slot? {
        slots[target] ?? slots.values.first { $0.lease?.id == target }
    }

    private func nextGeneration() -> Int {
        generationCounter += 1
        return generationCounter
    }

    private func changed() {
        let snapshot = snapshot()
        store?.save(snapshot.slots)
        for sink in watchers.values { sink.yield(.state(snapshot)) }
    }

    static func shortID() -> String {
        String(UUID().uuidString.lowercased().prefix(8))
    }
}
