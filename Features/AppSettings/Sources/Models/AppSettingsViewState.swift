public struct AppSettingsViewState: Equatable, Sendable {
    public let speedSource: SpeedSourceSettingsViewState
    public let dashboardProgressBarMode: DashboardProgressBarSettingsViewState
    public let dashboardBatteryIndicatorMode: AppSettingsSelectionViewState
    public let dashboardDeviceBatteryDisplayMode: AppSettingsSelectionViewState
    public let showsDashboardTemperatures: Bool
    public let measurementSystem: AppSettingsSelectionViewState
    public let batteryCapacity: AppSettingsSelectionViewState
    public let powerTier: PowerTierSettingsViewState
    public let rideDisplay: SettingsNavigationSummaryViewData
    public let dashboardCards: SettingsNavigationSummaryViewData
    public let powerModes: SettingsNavigationSummaryViewData

    public init(
        speedSource: SpeedSourceSettingsViewState,
        dashboardProgressBarMode: DashboardProgressBarSettingsViewState? = nil,
        dashboardBatteryIndicatorMode: AppSettingsSelectionViewState = .init(
            selectedID: "percentage",
            options: []
        ),
        dashboardDeviceBatteryDisplayMode: AppSettingsSelectionViewState = .init(
            selectedID: "iconAndText",
            options: []
        ),
        showsDashboardTemperatures: Bool = false,
        measurementSystem: AppSettingsSelectionViewState,
        batteryCapacity: AppSettingsSelectionViewState,
        powerTier: PowerTierSettingsViewState? = nil,
        rideDisplay: SettingsNavigationSummaryViewData? = nil,
        dashboardCards: SettingsNavigationSummaryViewData? = nil,
        powerModes: SettingsNavigationSummaryViewData? = nil
    ) {
        self.speedSource = speedSource
        self.dashboardProgressBarMode = dashboardProgressBarMode ?? .init(
            selection: .init(selectedID: "energy", options: []),
            description: .appSettingsProgressBarEnergyDescription
        )
        self.dashboardBatteryIndicatorMode = dashboardBatteryIndicatorMode
        self.dashboardDeviceBatteryDisplayMode = dashboardDeviceBatteryDisplayMode
        self.showsDashboardTemperatures = showsDashboardTemperatures
        self.measurementSystem = measurementSystem
        self.batteryCapacity = batteryCapacity
        self.powerTier = powerTier ?? .init(
            selection: .init(selectedID: "standard", options: []),
            status: .appSettingsPowerTierStandardBaseline
        )
        self.rideDisplay = rideDisplay ?? .init(detail: .appSettingsRideDisplayDefaultSummary)
        self.dashboardCards = dashboardCards ?? .init(detail: .appSettingsDashboardCardsDefaultSummary)
        self.powerModes = powerModes ?? .init(detail: .appSettingsPowerModesConfigured)
    }
}
