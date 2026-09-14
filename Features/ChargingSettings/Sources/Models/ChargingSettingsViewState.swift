public struct ChargingSettingsViewState: Equatable {
    public let power: Double
    public let target: Double
    public let maximumPower: Double
    public let selectedChargerID: String
    public let canSelectCharger: Bool
    public let canEditPower: Bool
    public let canEditTarget: Bool
    public let powerDetail: String
    public let targetDetail: String
    public let status: String
    public let isBusy: Bool
    public let hasPendingChanges: Bool
    public let canRetry: Bool
}
