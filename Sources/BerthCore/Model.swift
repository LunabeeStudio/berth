import Foundation

public struct Owner: Codable, Sendable, Hashable {
    public var pid: Int32
    public var startTime: Double?
    public var name: String

    public init(pid: Int32, startTime: Double?, name: String) {
        self.pid = pid
        self.startTime = startTime
        self.name = name
    }

    public var display: String { "\(name)#\(pid)" }
}

public enum SlotState: String, Codable, Sendable {
    case booting, free, leased, resetting, stopping
}

public struct Lease: Codable, Sendable, Hashable {
    public var id: String
    public var owner: Owner
    public var label: String?
    public var grantedAt: Date
    public var expiresAt: Date
    public var acknowledged: Bool

    public init(id: String, owner: Owner, label: String?, grantedAt: Date, expiresAt: Date, acknowledged: Bool) {
        self.id = id
        self.owner = owner
        self.label = label
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.acknowledged = acknowledged
    }
}

public struct Slot: Codable, Sendable, Identifiable {
    public var serial: String
    public var model: String
    public var pid: Int32?
    public var state: SlotState
    public var stateSince: Date
    public var lease: Lease?
    public var generation: Int

    public var id: String { serial }

    public init(serial: String, model: String, pid: Int32?, state: SlotState, stateSince: Date, lease: Lease? = nil, generation: Int) {
        self.serial = serial
        self.model = model
        self.pid = pid
        self.state = state
        self.stateSince = stateSince
        self.lease = lease
        self.generation = generation
    }
}

public struct WaiterInfo: Codable, Sendable, Identifiable {
    public var id: String
    public var owner: Owner
    public var label: String?
    public var model: String?
    public var enqueuedAt: Date

    public init(id: String, owner: Owner, label: String?, model: String?, enqueuedAt: Date) {
        self.id = id
        self.owner = owner
        self.label = label
        self.model = model
        self.enqueuedAt = enqueuedAt
    }
}

public struct StateSnapshot: Codable, Sendable {
    public var slots: [Slot]
    public var queue: [WaiterInfo]
    public var maxRunning: Int
    public var pool: [PoolEntry]
    public var generatedAt: Date

    public init(slots: [Slot], queue: [WaiterInfo], maxRunning: Int, pool: [PoolEntry], generatedAt: Date) {
        self.slots = slots
        self.queue = queue
        self.maxRunning = maxRunning
        self.pool = pool
        self.generatedAt = generatedAt
    }
}

public struct Grant: Codable, Sendable {
    public var serial: String
    public var model: String
    public var leaseID: String
    public var expiresAt: Date

    public init(serial: String, model: String, leaseID: String, expiresAt: Date) {
        self.serial = serial
        self.model = model
        self.leaseID = leaseID
        self.expiresAt = expiresAt
    }
}

extension String {
    public func numericallyPrecedes(_ other: String) -> Bool {
        compare(other, options: .numeric) == .orderedAscending
    }
}
