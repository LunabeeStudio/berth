public enum MirrorMode {
    case control
    case viewOnly

    public var titleSuffix: String {
        switch self {
        case .control: ""
        case .viewOnly: " (view only)"
        }
    }

    public var extraArguments: [String] {
        switch self {
        case .control: []
        case .viewOnly: ["--no-control"]
        }
    }
}
