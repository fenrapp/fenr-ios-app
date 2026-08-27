public struct DashboardProgressBarSettingsViewState: Equatable, Sendable {
    public let selection: AppSettingsSelectionViewState
    public let description: String

    public init(selection: AppSettingsSelectionViewState, description: String) {
        self.selection = selection
        self.description = description
    }
}
