public struct BikePowerModeCurveConfirmation: Equatable, Sendable {
    private let power: [Int]?
    private let regeneration: [Int]?

    public var hasAdvancedCurve: Bool { power != nil || regeneration != nil }

    public init() {
        power = nil
        regeneration = nil
    }

    private init(power: [Int]?, regeneration: [Int]?) {
        self.power = power
        self.regeneration = regeneration
    }

    public func confirming(
        _ value: BikeAdvancedPowerModeConfiguration,
        advancedEditBaseline: BikeAdvancedPowerModeConfiguration? = nil
    ) -> Self {
        let editedPower = advancedEditBaseline.map { $0.power != value.power } ?? false
        let editedRegeneration = advancedEditBaseline.map { $0.regeneration != value.regeneration } ?? false
        return .init(
            power: editedPower || power == value.power ? value.power : nil,
            regeneration: editedRegeneration || regeneration == value.regeneration ? value.regeneration : nil
        )
    }

    public func invalidating(power: Bool, regeneration: Bool) -> Self {
        .init(power: power ? nil : self.power, regeneration: regeneration ? nil : self.regeneration)
    }

    public func merging(_ other: Self) -> Self {
        .init(power: power ?? other.power, regeneration: regeneration ?? other.regeneration)
    }
}
