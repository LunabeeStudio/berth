public enum ScrcpyArguments {
    public static func make(serial: String, model: String, mode: MirrorMode) -> [String] {
        ["-s", serial, "--no-audio", "--window-title", "\(serial) \(model)\(mode.titleSuffix)"] + mode.extraArguments
    }
}
