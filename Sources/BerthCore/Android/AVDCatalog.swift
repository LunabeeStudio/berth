import Foundation

public enum AVDCatalog {
    public static var home: URL {
        let env: [String: String] = ProcessInfo.processInfo.environment
        if let home = env["ANDROID_AVD_HOME"], !home.isEmpty { return URL(fileURLWithPath: home) }
        if let user = env["ANDROID_USER_HOME"], !user.isEmpty { return URL(fileURLWithPath: user).appending(path: "avd") }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: ".android/avd")
    }

    public static func list(sdkRoot: String) async -> [String] {
        guard let result = try? await Shell.run("\(sdkRoot)/emulator/emulator", ["-list-avds"]) else { return [] }
        return result.stdout
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains(" ") && !$0.contains("|") }
    }

    public static func avds(config: Config) async -> [AVD] {
        await list(sdkRoot: config.resolvedSDKRoot).map { AVD(name: $0, prepared: hasSnapshot(config.snapshotName, model: $0)) }
    }

    public static func directory(of model: String, home: URL = AVDCatalog.home) -> URL {
        let ini: URL = home.appending(path: "\(model).ini")
        if
            let contents = try? String(contentsOf: ini, encoding: .utf8),
            let line = contents.split(whereSeparator: \.isNewline).first(where: { $0.hasPrefix("path=") })
        {
            return URL(fileURLWithPath: String(line.dropFirst("path=".count)))
        }
        return home.appending(path: "\(model).avd")
    }

    public static func hasSnapshot(_ snapshot: String, model: String, home: URL = AVDCatalog.home) -> Bool {
        FileManager.default.fileExists(atPath: directory(of: model, home: home).appending(path: "snapshots/\(snapshot)").path)
    }
}
