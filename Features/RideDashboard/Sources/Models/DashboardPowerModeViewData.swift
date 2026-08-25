public struct DashboardPowerModeViewData: Equatable, Sendable {
    public let map: String
    public let horsepower: String
    public let regenerativeBraking: String
    public let powerTraction: String
    public let brakingTraction: String
    public let showsTractionControl: Bool

    public init(
        map: String = "--",
        horsepower: String = "--",
        regenerativeBraking: String = "--",
        powerTraction: String = "--",
        brakingTraction: String = "--",
        showsTractionControl: Bool = false
    ) {
        self.map = map
        self.horsepower = horsepower
        self.regenerativeBraking = regenerativeBraking
        self.powerTraction = powerTraction
        self.brakingTraction = brakingTraction
        self.showsTractionControl = showsTractionControl
    }
}
