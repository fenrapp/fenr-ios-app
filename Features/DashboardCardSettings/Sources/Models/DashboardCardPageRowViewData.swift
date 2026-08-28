public struct DashboardCardPageRowViewData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let isVisible: Bool
    public let canHide: Bool
    public let thumbnail: DashboardCardThumbnailViewData

    public init(
        id: String,
        title: String,
        isVisible: Bool,
        canHide: Bool,
        thumbnail: DashboardCardThumbnailViewData
    ) {
        self.id = id
        self.title = title
        self.isVisible = isVisible
        self.canHide = canHide
        self.thumbnail = thumbnail
    }
}
