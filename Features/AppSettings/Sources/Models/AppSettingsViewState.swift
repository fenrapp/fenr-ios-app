public struct AppSettingsViewState: Equatable, Sendable {
    public let speedSource: SpeedSourceSettingsViewState
    public let dashboardProgressBarMode: DashboardProgressBarSettingsViewState
    public let dashboardBatteryIndicatorMode: AppSettingsSelectionViewState
    public let showsDashboardTemperatures: Bool
    public let measurementSystem: AppSettingsSelectionViewState
    public let batteryCapacity: AppSettingsSelectionViewState
    public let powerTier: PowerTierSettingsViewState

    public init(
        speedSource: SpeedSourceSettingsViewState,
        dashboardProgressBarMode: DashboardProgressBarSettingsViewState = .init(
            selection: .init(selectedID: "energy", options: []),
            description: "Regeneration fills left from the center; consumption fills right."
        ),
        dashboardBatteryIndicatorMode: AppSettingsSelectionViewState = .init(
            selectedID: "percentage",
            options: []
        ),
        showsDashboardTemperatures: Bool = false,
        measurementSystem: AppSettingsSelectionViewState,
        batteryCapacity: AppSettingsSelectionViewState,
        powerTier: PowerTierSettingsViewState = .init(
            selection: .init(selectedID: "standard", options: []),
            status: "Standard baseline"
        )
    ) {
        self.speedSource = speedSource
        self.dashboardProgressBarMode = dashboardProgressBarMode
        self.dashboardBatteryIndicatorMode = dashboardBatteryIndicatorMode
        self.showsDashboardTemperatures = showsDashboardTemperatures
        self.measurementSystem = measurementSystem
        self.batteryCapacity = batteryCapacity
        self.powerTier = powerTier
    }
}
