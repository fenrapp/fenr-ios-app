public struct DashboardCardFixedRowViewData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let thumbnail: DashboardCardThumbnailViewData

    public init(
        id: String,
        title: String,
        detail: String,
        thumbnail: DashboardCardThumbnailViewData
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.thumbnail = thumbnail
    }
}
