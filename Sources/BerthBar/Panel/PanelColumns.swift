import CoreGraphics

enum PanelColumns {
    static let spacing: CGFloat = 8
    static let serial: CGFloat = 105
    static let model: CGFloat = 90
    static let state: CGFloat = 70
    static let owner: CGFloat = 95
    static let label: CGFloat = 70
    static let held: CGFloat = 55
    static let remaining: CGFloat = 60
    static let mirror: CGFloat = 22

    static var detailSpan: CGFloat {
        let columns: [CGFloat] = [state, owner, label, held, remaining]
        return columns.reduce(0, +) + spacing * CGFloat(columns.count - 1)
    }
}
