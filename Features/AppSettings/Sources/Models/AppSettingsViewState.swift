public struct AppSettingsViewState: Equatable, Sendable {
    public let speedSource: SpeedSourceSettingsViewState
    public let measurementSystem: AppSettingsSelectionViewState
    public let batteryCapacity: AppSettingsSelectionViewState

    public init(
        speedSource: SpeedSourceSettingsViewState,
        measurementSystem: AppSettingsSelectionViewState,
        batteryCapacity: AppSettingsSelectionViewState
    ) {
        self.speedSource = speedSource
        self.measurementSystem = measurementSystem
        self.batteryCapacity = batteryCapacity
    }
}
