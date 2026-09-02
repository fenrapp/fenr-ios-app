import Foundation

public struct DashboardProgressBarSettingsViewState: Equatable, Sendable {
    public let selection: AppSettingsSelectionViewState
    public let description: LocalizedStringResource

    public init(selection: AppSettingsSelectionViewState, description: LocalizedStringResource) {
        self.selection = selection
        self.description = description
    }
}
