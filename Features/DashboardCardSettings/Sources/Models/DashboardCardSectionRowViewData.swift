import Foundation

public struct DashboardCardSectionRowViewData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: LocalizedStringResource
    public let detail: LocalizedStringResource
    public let isVisible: Bool
    public let isVisibilityEnabled: Bool
    public let disabledVisibilityHint: LocalizedStringResource?
    public let thumbnail: DashboardCardThumbnailViewData
    public let pages: [DashboardCardPageRowViewData]

    public init(
        id: String,
        title: LocalizedStringResource,
        detail: LocalizedStringResource,
        isVisible: Bool,
        isVisibilityEnabled: Bool = true,
        disabledVisibilityHint: LocalizedStringResource? = nil,
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
