public struct DashboardCardSectionRowViewData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let isVisible: Bool
    public let isVisibilityEnabled: Bool
    public let disabledVisibilityHint: String?
    public let thumbnail: DashboardCardThumbnailViewData
    public let pages: [DashboardCardPageRowViewData]

    public init(
        id: String,
        title: String,
        detail: String,
        isVisible: Bool,
        isVisibilityEnabled: Bool = true,
        disabledVisibilityHint: String? = nil,
        thumbnail: DashboardCardThumbnailViewData,
        pages: [DashboardCardPageRowViewData]
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isVisible = isVisible
        self.isVisibilityEnabled = isVisibilityEnabled
        self.disabledVisibilityHint = disabledVisibilityHint
        self.thumbnail = thumbnail
        self.pages = pages
    }
}
