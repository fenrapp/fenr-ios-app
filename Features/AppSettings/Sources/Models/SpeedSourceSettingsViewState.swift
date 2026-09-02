import Foundation

public struct SpeedSourceSettingsViewState: Equatable, Sendable {
    public let selection: AppSettingsSelectionViewState
    public let description: LocalizedStringResource
    public let locationPermission: LocationPermissionViewState?

    public init(
        selection: AppSettingsSelectionViewState,
        description: LocalizedStringResource,
        locationPermission: LocationPermissionViewState?
    ) {
        self.selection = selection
        self.description = description
        self.locationPermission = locationPermission
    }
}
