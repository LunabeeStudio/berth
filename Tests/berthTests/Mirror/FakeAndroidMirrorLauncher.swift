import Foundation

@testable import berth

final class FakeAndroidMirrorLauncher: AndroidMirrorLauncher, @unchecked Sendable {
    struct Launch: Equatable {
        let executable: String
        let arguments: [String]
        let log: URL
        let environment: [String: String]
    }

    private(set) var launches: [Launch] = []
    var failure: (any Error)?

    func launch(executable: String, arguments: [String], log: URL, environment: [String: String]) throws {
        if let failure { throw failure }
        launches.append(.init(executable: executable, arguments: arguments, log: log, environment: environment))
    }
}
