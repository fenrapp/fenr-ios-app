public struct RideNavigationRoadRouteOption: Equatable, Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let detail: String
    public let isSelected: Bool

    public init(id: Int, title: String, detail: String, isSelected: Bool) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isSelected = isSelected
    }
}
