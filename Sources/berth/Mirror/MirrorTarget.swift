enum MirrorTarget: Equatable {
    case android(serial: String, name: String)
    case ios(udid: String)
}
