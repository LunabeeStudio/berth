enum MirrorMode {
    case control
    case viewOnly

    var titleSuffix: String {
        switch self {
        case .control: ""
        case .viewOnly: " (view only)"
        }
    }

    var extraArguments: [String] {
        switch self {
        case .control: []
        case .viewOnly: ["--no-control"]
        }
    }
}
