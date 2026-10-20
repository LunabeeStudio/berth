import BerthCore
import Foundation
import Synchronization

public final class IOSSimulatorBackend: DeviceBackend {
    public static let namePrefix = "berth-"

    private struct State {
        var udids: [String: [String]] = [:]
        var failures: [String: String] = [:]
        var owned: Set<String> = []
    }

    private let xcrun = "/usr/bin/xcrun"
    private let entries: [PoolEntry]
    private let bootTimeout: Duration
    private let state = Mutex(State())

    public init(config: Config) {
        entries = config.entries(for: .ios)
        bootTimeout = .seconds(config.bootTimeoutSeconds)
    }

    public static func deviceName(simulator: String, index: Int) -> String {
        "\(namePrefix)\(simulator)-\(index)"
    }

    public static func parseDevices(_ data: Data) -> [SimulatorDevice]? {
        struct Listing: Decodable {
            struct Device: Decodable {
                var udid: String
                var name: String
                var state: String
                var isAvailable: Bool?
            }

            var devices: [String: [Device]]
        }
        guard let listing = try? JSONDecoder().decode(Listing.self, from: data) else { return nil }
        return listing.devices.values.flatMap { $0 }
            .filter { $0.isAvailable ?? true }
            .map { SimulatorDevice(udid: $0.udid, name: $0.name, isBooted: $0.state == "Booted") }
    }

    public static func liveSerials(in devices: [SimulatorDevice]) -> Set<String> {
        Set(devices.filter { $0.isBerthOwned && $0.isBooted }.map(\.udid))
    }

    public func provision() async {
        guard !entries.isEmpty else { return }
        guard let existing = await listDevices() else {
            let reason = "xcrun simctl list devices failed"
            Log.info("ios: \(reason)")
            state.withLock { state in
                for entry in entries { state.failures[entry.name] = reason }
            }
            return
        }
        for entry in entries {
            var udids: [String] = []
            for index in 0..<entry.maxInstances {
                let name = Self.deviceName(simulator: entry.name, index: index + 1)
                if let device = existing.first(where: { $0.name == name }) {
                    udids.append(device.udid)
                    continue
                }
                do {
                    let result = try await simctl("create", name, entry.name, timeout: .seconds(60))
                    udids.append(result.trimmedOutput)
                    Log.info("ios: created \(name) (\(result.trimmedOutput))")
                } catch {
                    Log.info("ios: \(entry.name): \(error)")
                    state.withLock { $0.failures[entry.name] = "\(error)" }
                    break
                }
            }
            state.withLock { $0.udids[entry.name] = udids }
        }
        state.withLock { $0.owned = Set(existing.filter(\.isBerthOwned).map(\.udid)).union($0.udids.values.flatMap { $0 }) }
    }

    public func unavailableReason(model: String) -> String? {
        state.withLock { state in
            guard state.udids[model]?.isEmpty ?? true else { return nil }
            return state.failures[model] ?? "no berth simulator exists for '\(model)'"
        }
    }

    public func nextSerial(model: String, taken: Set<String>) -> String? {
        state.withLock { $0.udids[model]?.first { !taken.contains($0) } }
    }

    public func launch(serial: String, model: String, windowed: Bool) async throws -> Int32? {
        try requireOwned(serial)
        _ = try? await simctl("shutdown", serial)
        _ = try await simctl("erase", serial)
        _ = try await simctl("boot", serial)
        return nil
    }

    public func waitReady(serial: String, pid: Int32?) async throws {
        try requireOwned(serial)
        _ = try await simctl("bootstatus", serial, timeout: bootTimeout, onTimeout: .bootTimeout(serial))
    }

    public func reset(serial: String, model: String, pid: Int32?, windowed: Bool) async throws -> Int32? {
        let newPID = try await launch(serial: serial, model: model, windowed: false)
        try await waitReady(serial: serial, pid: newPID)
        return newPID
    }

    public func shutdown(serial: String, pid: Int32?) async {
        guard state.withLock({ $0.owned.contains(serial) }) else { return }
        _ = try? await simctl("shutdown", serial, timeout: .seconds(60))
    }

    public func liveSerials() async -> Set<String>? {
        await listDevices().map(Self.liveSerials(in:))
    }

    public func isProcessAlive(_ pid: Int32) -> Bool { true }

    private func requireOwned(_ serial: String) throws {
        guard state.withLock({ $0.owned.contains(serial) }) else {
            throw BackendError.command("simctl", "\(serial) is not a berth simulator")
        }
    }

    private func simctl(_ arguments: String..., timeout: Duration = .seconds(120), onTimeout: BackendError? = nil) async throws -> ShellResult {
        let result = try await Shell.run(xcrun, ["simctl"] + arguments, timeout: timeout)
        if result.timedOut, let onTimeout { throw onTimeout }
        guard result.succeeded else {
            let output = result.timedOut ? "timed out" : result.stderr + result.stdout
            throw BackendError.command("simctl \(arguments.joined(separator: " "))", output)
        }
        return result
    }

    private func listDevices() async -> [SimulatorDevice]? {
        guard let result = try? await simctl("list", "devices", "-j", timeout: .seconds(30)) else { return nil }
        return Self.parseDevices(Data(result.stdout.utf8))
    }
}
