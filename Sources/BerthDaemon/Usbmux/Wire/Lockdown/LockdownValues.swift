struct LockdownValues: Equatable {
    static let unavailable: LockdownValues = .init(name: nil, productType: nil, osVersion: nil)

    let name: String?
    let productType: String?
    let osVersion: String?
}
