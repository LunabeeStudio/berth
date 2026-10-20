import Foundation

public struct PoolEntry: Codable, Sendable, Hashable {
    public var name: String
    public var platform: Platform
    public var maxInstances: Int

    public init(name: String, platform: Platform = .android, maxInstances: Int) {
        self.name = name
        self.platform = platform
        self.maxInstances = maxInstances
    }

    private enum CodingKeys: String, CodingKey {
        case avd
        case simulator
        case maxInstances
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        maxInstances = try c.decode(Int.self, forKey: .maxInstances)
        if let avd = try c.decodeIfPresent(String.self, forKey: .avd) {
            name = avd
            platform = .android
        } else if let simulator = try c.decodeIfPresent(String.self, forKey: .simulator) {
            name = simulator
            platform = .ios
        } else {
            throw DecodingError.keyNotFound(CodingKeys.avd, .init(codingPath: c.codingPath, debugDescription: "pool entry needs 'avd' or 'simulator'"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: platform == .android ? .avd : .simulator)
        try c.encode(maxInstances, forKey: .maxInstances)
    }
}

public struct Config: Codable, Sendable {
    public var sdkRoot: String?
    public var maxRunning: Int
    public var idleShutdownSeconds: Int
    public var defaultTTLSeconds: Int
    public var bootTimeoutSeconds: Int
    public var snapshotName: String
    public var autoUpdate: Bool
    public var pool: [PoolEntry]

    public init(
        sdkRoot: String? = nil,
        maxRunning: Int = 4,
        idleShutdownSeconds: Int = 900,
        defaultTTLSeconds: Int = 3600,
        bootTimeoutSeconds: Int = 300,
        snapshotName: String = "berth-clean",
        autoUpdate: Bool = true,
        pool: [PoolEntry] = []
    ) {
        self.sdkRoot = sdkRoot
        self.maxRunning = maxRunning
        self.idleShutdownSeconds = idleShutdownSeconds
        self.defaultTTLSeconds = defaultTTLSeconds
        self.bootTimeoutSeconds = bootTimeoutSeconds
        self.snapshotName = snapshotName
        self.autoUpdate = autoUpdate
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
        autoUpdate = try c.decodeIfPresent(Bool.self, forKey: .autoUpdate) ?? defaults.autoUpdate
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

    public var adbPath: String {
        URL(fileURLWithPath: resolvedSDKRoot).appending(path: "platform-tools/adb").path
    }

    public func platform(of model: String) -> Platform {
        pool.platform(of: model)
    }

    public func entries(for platform: Platform) -> [PoolEntry] {
        pool.filter { $0.platform == platform }
    }

    public func models(for platform: Platform) -> [String] {
        entries(for: platform).map(\.name)
    }

    public func entry(for model: String) -> PoolEntry? {
        pool.entry(for: model)
    }

    public static func load(from url: URL = Paths.config) throws -> Config? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try JSONDecoder().decode(Config.self, from: data)
    }

    public static func setAutoUpdate(_ value: Bool, at url: URL = Paths.config) throws {
        let data: Data = try Data(contentsOf: url)
        _ = try JSONDecoder().decode(Config.self, from: data)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "config is not a JSON object"))
        }
        object[CodingKeys.autoUpdate.stringValue] = value
        let updated: Data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try updated.write(to: url, options: .atomic)
    }

    public static func loadOrCreate(discoverModels: (String) async -> [String]) async throws -> Config {
        if let config = try load() {
            return config
        }
        var config = Config()
        config.sdkRoot = config.resolvedSDKRoot
        config.pool = await discoverModels(config.resolvedSDKRoot).map { PoolEntry(name: $0, maxInstances: 2) }
        try Paths.ensureDirectories()
        try config.save()
        return config
    }

    public static func defaultADBPath() -> String {
        ((try? load()) ?? .init()).adbPath
    }

    public func save(to url: URL = Paths.config) throws {
        let encoder: JSONEncoder = .init()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
