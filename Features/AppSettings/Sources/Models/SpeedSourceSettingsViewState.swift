public struct SpeedSourceSettingsViewState: Equatable, Sendable {
    public let selection: AppSettingsSelectionViewState
    public let description: String
    public let locationPermission: LocationPermissionViewState?

    public init(
        selection: AppSettingsSelectionViewState,
        description: String,
        locationPermission: LocationPermissionViewState?
    ) {
        self.selection = selection
        self.description = description
        self.locationPermission = locationPermission
    }
}
