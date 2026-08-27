public struct AppSettingsViewState: Equatable, Sendable {
    public let speedSource: SpeedSourceSettingsViewState
    public let dashboardProgressBarMode: DashboardProgressBarSettingsViewState
    public let measurementSystem: AppSettingsSelectionViewState
    public let batteryCapacity: AppSettingsSelectionViewState
    public let powerTier: PowerTierSettingsViewState

    public init(
        speedSource: SpeedSourceSettingsViewState,
        dashboardProgressBarMode: DashboardProgressBarSettingsViewState = .init(
            selection: .init(selectedID: "energy", options: []),
            description: "Regeneration fills left from the center; consumption fills right."
        ),
        measurementSystem: AppSettingsSelectionViewState,
        batteryCapacity: AppSettingsSelectionViewState,
        powerTier: PowerTierSettingsViewState = .init(
            selection: .init(selectedID: "standard", options: []),
            status: "Standard baseline"
        )
    ) {
        self.speedSource = speedSource
        self.dashboardProgressBarMode = dashboardProgressBarMode
        self.measurementSystem = measurementSystem
        self.batteryCapacity = batteryCapacity
        self.powerTier = powerTier
    }
}
