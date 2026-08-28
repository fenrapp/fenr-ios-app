public struct DashboardCardSectionRowViewData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let isVisible: Bool
    public let thumbnail: DashboardCardThumbnailViewData
    public let pages: [DashboardCardPageRowViewData]

    public init(
        id: String,
        title: String,
        detail: String,
        isVisible: Bool,
        thumbnail: DashboardCardThumbnailViewData,
        pages: [DashboardCardPageRowViewData]
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isVisible = isVisible
        self.thumbnail = thumbnail
        self.pages = pages
    }
}
