public enum ChargeControlPhase: Equatable, Sendable {
    case unavailable
    case preparing
    case ready
    case updating
    case failed
}

public struct ChargeControlState: Equatable, Sendable {
    public internal(set) var isVisible: Bool
    public internal(set) var isEnabled: Bool
    public internal(set) var selectedWatts: Double
    public internal(set) var confirmedWatts: Int?
    public internal(set) var minimumWatts: Double
    public internal(set) var maximumWatts: Double
    public internal(set) var stepWatts: Double
    public internal(set) var selectedTargetPercent: Double
    public internal(set) var confirmedTargetPercent: Int?
    public internal(set) var minimumTargetPercent: Double
    public internal(set) var maximumTargetPercent: Double
    public internal(set) var targetStepPercent: Double
    public internal(set) var chargerType: String
    public internal(set) var status: String
    public internal(set) var error: String?
    public internal(set) var phase: ChargeControlPhase

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
        error: String? = nil,
        phase: ChargeControlPhase = .unavailable
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
        self.phase = phase
    }
}
