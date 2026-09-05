import Foundation

public struct LiveActivitySettingsViewState: Equatable, Sendable {
    public struct Activity: Equatable, Identifiable, Sendable {
        public let id: String
        public let title: LocalizedStringResource
        public let detail: LocalizedStringResource
        public let isEnabled: Bool
        public let presentation: AppSettingsSelectionViewState
    }

    public let isEnabled: Bool
    public let summary: LocalizedStringResource
    public let activities: [Activity]

    public init(
        isEnabled: Bool = true,
        summary: LocalizedStringResource? = nil,
        activities: [Activity] = []
    ) {
        self.isEnabled = isEnabled
        self.summary = summary ?? .appSettingsLiveActivitiesSummary
        self.activities = activities
    }
}
