import Foundation

public struct SettingsNavigationSummaryViewData: Equatable, Sendable {
    public let detail: LocalizedStringResource

    public init(detail: LocalizedStringResource) {
        self.detail = detail
    }
}
