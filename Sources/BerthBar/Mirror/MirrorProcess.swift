protocol MirrorProcess {
    var pid: Int32 { get }
    func terminate()
}
