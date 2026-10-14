import Foundation

public struct PoolEntry: Codable, Sendable, Hashable {
    public var avd: String
    public var maxInstances: Int

    public init(avd: String, maxInstances: Int) {
        self.avd = avd
        self.maxInstances = maxInstances
    }
}

public struct Config: Codable, Sendable {
    public var sdkRoot: String?
    public var maxRunning: Int
    public var idleShutdownSeconds: Int
    public var defaultTTLSeconds: Int
    public var bootTimeoutSeconds: Int
    public var snapshotName: String
    public var pool: [PoolEntry]

    public init(
        sdkRoot: String? = nil,
        maxRunning: Int = 4,
        idleShutdownSeconds: Int = 900,
        defaultTTLSeconds: Int = 3600,
        bootTimeoutSeconds: Int = 300,
        snapshotName: String = "berth-clean",
        pool: [PoolEntry] = []
    ) {
        self.sdkRoot = sdkRoot
        self.maxRunning = maxRunning
        self.idleShutdownSeconds = idleShutdownSeconds
        self.defaultTTLSeconds = defaultTTLSeconds
        self.bootTimeoutSeconds = bootTimeoutSeconds
        self.snapshotName = snapshotName
        self.pool = pool
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Config()
        sdkRoot = try c.decodeIfPresent(String.self, forKey: .sdkRoot)
        maxRunning = try c.decodeIfPresent(Int.self, forKey: .maxRunning) ?? defaults.maxRunning
        idleShutdownSeconds = try c.decodeIfPresent(Int.self, forKey: .idleShutdownSeconds) ?? defaults.idleShutdownSeconds
        defaultTTLSeconds = try c.decodeIfPresent(Int.self, forKey: .defaultTTLSeconds) ?? defaults.defaultTTLSeconds
        bootTimeoutSeconds = try c.decodeIfPresent(Int.self, forKey: .bootTimeoutSeconds) ?? defaults.bootTimeoutSeconds
        snapshotName = try c.decodeIfPresent(String.self, forKey: .snapshotName) ?? defaults.snapshotName
        pool = try c.decodeIfPresent([PoolEntry].self, forKey: .pool) ?? []
    }

    public var resolvedSDKRoot: String {
        if let sdkRoot, !sdkRoot.isEmpty { return (sdkRoot as NSString).expandingTildeInPath }
        let env = ProcessInfo.processInfo.environment
        for key in ["ANDROID_HOME", "ANDROID_SDK_ROOT"] {
            if let value = env[key], !value.isEmpty { return value }
        }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Android/sdk").path
    }

    public func entry(for model: String) -> PoolEntry? {
        pool.first { $0.avd == model }
    }

    public static func loadOrCreate(discoverModels: (String) async -> [String]) async throws -> Config {
        if let data = try? Data(contentsOf: Paths.config) {
            return try JSONDecoder().decode(Config.self, from: data)
        }
        var config = Config()
        config.sdkRoot = config.resolvedSDKRoot
        config.pool = await discoverModels(config.resolvedSDKRoot).map { PoolEntry(avd: $0, maxInstances: 2) }
        try Paths.ensureDirectories()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: Paths.config, options: .atomic)
        return config
    }
}
