public struct BikeLockSecurityOptionViewData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let requiresPIN: Bool

    public init(id: String, title: String, detail: String, requiresPIN: Bool) {
        self.id = id
        self.title = title
        self.detail = detail
        self.requiresPIN = requiresPIN
    }
}
