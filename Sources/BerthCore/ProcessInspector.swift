import Darwin

public struct ProcessDetails: Sendable {
    public var pid: Int32
    public var parentPID: Int32
    public var name: String
    public var startTime: Double
}

public enum ProcessInspector {
    public static func details(of pid: Int32) -> ProcessDetails? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let name = withUnsafeBytes(of: info.kp_proc.p_comm) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        let start = info.kp_proc.p_un.__p_starttime
        return ProcessDetails(
            pid: pid,
            parentPID: info.kp_eproc.e_ppid,
            name: name,
            startTime: Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000
        )
    }

    /// Start time is compared too so a recycled PID is not mistaken for the original owner.
    public static func isAlive(_ owner: Owner) -> Bool {
        guard let details = details(of: owner.pid) else { return false }
        guard let start = owner.startTime else { return true }
        return abs(details.startTime - start) < 1
    }

    public static func owner(pid: Int32) -> Owner? {
        details(of: pid).map(owner)
    }

    static func owner(_ details: ProcessDetails) -> Owner {
        Owner(pid: details.pid, startTime: details.startTime, name: displayName(details))
    }

    /// Versioned installs such as `~/.local/share/claude/versions/2.1.299` name the binary after its version.
    static func displayName(_ details: ProcessDetails) -> String {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(details.pid, &buffer, UInt32(buffer.count)) > 0 else { return details.name }
        let isVersion: (String) -> Bool = { $0.allSatisfy { $0.isNumber || $0 == "." } }
        let path = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        let components = path.split(separator: "/").map(String.init)
        guard let last = components.last, isVersion(last) else { return details.name }
        return components.reversed().first { !isVersion($0) && $0 != "versions" } ?? details.name
    }

    static let transparentProcesses: Set<String> = [
        "sh", "bash", "zsh", "fish", "dash", "ksh", "tcsh", "csh",
        "env", "timeout", "gtimeout", "nohup", "sudo", "time", "xargs", "rtk", "berth",
    ]

    /// Nearest non-shell ancestor, i.e. the agent itself, so its leases are reclaimed when the session ends.
    public static func detectOwner() -> Owner {
        var pid = getppid()
        var nearest: ProcessDetails?
        while pid > 1, let details = details(of: pid) {
            if nearest == nil { nearest = details }
            let name = details.name.hasPrefix("-") ? String(details.name.dropFirst()) : details.name
            if !transparentProcesses.contains(name) {
                return owner(details)
            }
            pid = details.parentPID
        }
        if let nearest { return owner(nearest) }
        return owner(pid: getpid()) ?? Owner(pid: getpid(), startTime: nil, name: "berth")
    }

    public static func isProcessAlive(_ pid: Int32) -> Bool {
        var status: Int32 = 0
        switch waitpid(pid, &status, WNOHANG) {
        case pid: return false
        case 0: return true
        default: return kill(pid, 0) == 0 || errno == EPERM
        }
    }
}
