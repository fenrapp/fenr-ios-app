import Foundation

public struct DashboardCardFixedRowViewData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: LocalizedStringResource
    public let detail: LocalizedStringResource
    public let thumbnail: DashboardCardThumbnailViewData

    public init(
        id: String,
        title: LocalizedStringResource,
        detail: LocalizedStringResource,
        thumbnail: DashboardCardThumbnailViewData
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.thumbnail = thumbnail
    }
}
