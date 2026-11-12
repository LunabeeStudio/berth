public enum ScrcpyArguments {
    public static func make(serial: String, name: String, mode: MirrorMode) -> [String] {
        ["-s", serial, "--no-audio", "--window-title", "\(serial) \(name)\(mode.titleSuffix)"] + mode.extraArguments
    }
}
