public struct AppSettingsViewState: Equatable, Sendable {
    public let speedSource: SpeedSourceSettingsViewState
    public let dashboardProgressBarMode: DashboardProgressBarSettingsViewState
    public let dashboardBatteryIndicatorMode: AppSettingsSelectionViewState
    public let dashboardDeviceBatteryDisplayMode: AppSettingsSelectionViewState
    public let dashboardTemperatureDisplayMode: AppSettingsSelectionViewState
    public let measurementSystem: AppSettingsSelectionViewState
    public let batteryCapacity: AppSettingsSelectionViewState
    public let powerTier: PowerTierSettingsViewState
    public let isBikeModelSelectionVisible: Bool
    public let rideDisplay: SettingsNavigationSummaryViewData
    public let dashboardCards: SettingsNavigationSummaryViewData
    public let powerModes: SettingsNavigationSummaryViewData
    public let navigation: SettingsNavigationSummaryViewData
    public let liveActivities: LiveActivitySettingsViewState
    public let navigationSettings: NavigationSettingsViewState

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
        dashboardTemperatureDisplayMode: AppSettingsSelectionViewState = .init(
            selectedID: "off",
            options: []
        ),
        measurementSystem: AppSettingsSelectionViewState,
        batteryCapacity: AppSettingsSelectionViewState,
        powerTier: PowerTierSettingsViewState? = nil,
        isBikeModelSelectionVisible: Bool = true,
        rideDisplay: SettingsNavigationSummaryViewData? = nil,
        dashboardCards: SettingsNavigationSummaryViewData? = nil,
        powerModes: SettingsNavigationSummaryViewData? = nil,
        navigation: SettingsNavigationSummaryViewData? = nil,
        navigationSettings: NavigationSettingsViewState = .init(),
        liveActivities: LiveActivitySettingsViewState = .init()
    ) {
        self.speedSource = speedSource
        self.dashboardProgressBarMode = dashboardProgressBarMode ?? .init(
            selection: .init(selectedID: "energy", options: []),
            description: .appSettingsProgressBarEnergyDescription
        )
        self.dashboardBatteryIndicatorMode = dashboardBatteryIndicatorMode
        self.dashboardDeviceBatteryDisplayMode = dashboardDeviceBatteryDisplayMode
        self.dashboardTemperatureDisplayMode = dashboardTemperatureDisplayMode
        self.measurementSystem = measurementSystem
        self.batteryCapacity = batteryCapacity
        self.powerTier = powerTier ?? .init(
            selection: .init(selectedID: "standard", options: []),
            status: .appSettingsPowerTierStandardBaseline
        )
        self.isBikeModelSelectionVisible = isBikeModelSelectionVisible
        self.rideDisplay = rideDisplay ?? .init(detail: .appSettingsRideDisplayDefaultSummary)
        self.dashboardCards = dashboardCards ?? .init(detail: .appSettingsDashboardCardsDefaultSummary)
        self.powerModes = powerModes ?? .init(detail: .appSettingsPowerModesConfigured)
        self.navigation = navigation ?? .init(detail: .appSettingsNavigationDetail)
        self.navigationSettings = navigationSettings
        self.liveActivities = liveActivities
    }
}
