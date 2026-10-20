enum MirrorTarget: Equatable {
    case android(serial: String, model: String)
    case ios(udid: String)
}
