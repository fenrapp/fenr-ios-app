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
        dashboardProgressBarMode: DashboardProgressBarSettingsViewState = .init(
            selection: .init(selectedID: "energy", options: []),
            description: "Regeneration fills left from the center; consumption fills right."
        ),
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
        powerTier: PowerTierSettingsViewState = .init(
            selection: .init(selectedID: "standard", options: []),
            status: "Standard baseline"
        ),
        rideDisplay: SettingsNavigationSummaryViewData = .init(detail: "Energy · Bike"),
        dashboardCards: SettingsNavigationSummaryViewData = .init(detail: "Order and visibility"),
        powerModes: SettingsNavigationSummaryViewData = .init(detail: "5 maps configured")
    ) {
        self.speedSource = speedSource
        self.dashboardProgressBarMode = dashboardProgressBarMode
        self.dashboardBatteryIndicatorMode = dashboardBatteryIndicatorMode
        self.dashboardDeviceBatteryDisplayMode = dashboardDeviceBatteryDisplayMode
        self.showsDashboardTemperatures = showsDashboardTemperatures
        self.measurementSystem = measurementSystem
        self.batteryCapacity = batteryCapacity
        self.powerTier = powerTier
        self.rideDisplay = rideDisplay
        self.dashboardCards = dashboardCards
        self.powerModes = powerModes
    }
}
