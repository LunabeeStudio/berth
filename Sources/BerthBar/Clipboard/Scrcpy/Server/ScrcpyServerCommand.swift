import Foundation

struct ScrcpyServerCommand: Equatable {
    static let jarPath: String = "/data/local/tmp/berth-scrcpy-server.jar"

    let version: String
    let scid: Int

    var socketName: String { "localabstract:scrcpy_\(scidHex)" }

    private var scidHex: String { String(format: "%08x", scid) }

    static func randomScid() -> Int {
        .random(in: 0 ..< 1 << 31)
    }

    func adbArguments(serial: String) -> [String] {
        [
            "-s", serial, "shell",
            "CLASSPATH=\(Self.jarPath)", "app_process", "/", "com.genymobile.scrcpy.Server", version,
            "scid=\(scidHex)",
            "log_level=warn",
            "tunnel_forward=true",
            "video=false",
            "audio=false",
            "control=true",
            "send_device_meta=false",
            "power_on=false",
            "cleanup=false",
            "clipboard_autosync=false",
        ]
    }

    /// A server that never got a client waits on its socket forever: only its scid tells it from a running mirror's server.
    /// `[s]` keeps the pattern from matching the shell that runs `pkill`.
    func killArguments(serial: String) -> [String] {
        ["-s", serial, "shell", "pkill -f 'com.genymobile.[s]crcpy.Server .*scid=\(scidHex)'"]
    }

    func forwardEndpoints(in listing: String, serial: String) -> [String] {
        listing.split(whereSeparator: \.isNewline)
            .map { $0.split(separator: " ").map(String.init) }
            .filter { $0.count == 3 && $0[0] == serial && $0[2] == socketName }
            .map { $0[1] }
    }
}
