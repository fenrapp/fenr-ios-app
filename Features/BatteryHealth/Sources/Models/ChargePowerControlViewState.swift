public struct ChargePowerControlViewState: Equatable, Sendable {
    public var isVisible: Bool
    public var isEnabled: Bool
    public var selectedWatts: Double
    public var confirmedWatts: Int?
    public var minimumWatts: Double
    public var maximumWatts: Double
    public var stepWatts: Double
    public var selectedTargetPercent: Double
    public var confirmedTargetPercent: Int?
    public var minimumTargetPercent: Double
    public var maximumTargetPercent: Double
    public var targetStepPercent: Double
    public var chargerType: String
    public var status: String
    public var error: String?

    public init(
        isVisible: Bool = false,
        isEnabled: Bool = false,
        selectedWatts: Double = 300,
        confirmedWatts: Int? = nil,
        minimumWatts: Double = 300,
        maximumWatts: Double = 3_300,
        stepWatts: Double = 100,
        selectedTargetPercent: Double = 100,
        confirmedTargetPercent: Int? = nil,
        minimumTargetPercent: Double = 1,
        maximumTargetPercent: Double = 100,
        targetStepPercent: Double = 1,
        chargerType: String = "Unknown",
        status: String = "Unavailable",
        error: String? = nil
    ) {
        self.isVisible = isVisible
        self.isEnabled = isEnabled
        self.selectedWatts = selectedWatts
        self.confirmedWatts = confirmedWatts
        self.minimumWatts = minimumWatts
        self.maximumWatts = maximumWatts
        self.stepWatts = stepWatts
        self.selectedTargetPercent = selectedTargetPercent
        self.confirmedTargetPercent = confirmedTargetPercent
        self.minimumTargetPercent = minimumTargetPercent
        self.maximumTargetPercent = maximumTargetPercent
        self.targetStepPercent = targetStepPercent
        self.chargerType = chargerType
        self.status = status
        self.error = error
    }
}
