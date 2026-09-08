import Foundation

public struct DashboardProgressBarSettingsViewState: Equatable, Sendable {
    public let selection: AppSettingsSelectionViewState
    public let thickness: AppSettingsSelectionViewState?
    public let description: LocalizedStringResource

    public init(
        selection: AppSettingsSelectionViewState,
        description: LocalizedStringResource,
        thickness: AppSettingsSelectionViewState? = nil
    ) {
        self.thickness = thickness
        self.selection = selection
        self.description = description
    }
}
