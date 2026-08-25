public struct BikePowerModeConfiguration: Equatable, Sendable {
    public let mapIndex: Int
    public var horsepower: Int?
    public var regenerativeBrakingPercent: Double?
    public var powerTractionPercent: Double?
    public var brakingTractionPercent: Double?

    public init(
        mapIndex: Int,
        horsepower: Int? = nil,
        regenerativeBrakingPercent: Double? = nil,
        powerTractionPercent: Double? = nil,
        brakingTractionPercent: Double? = nil
    ) {
        self.mapIndex = mapIndex
        self.horsepower = horsepower
        self.regenerativeBrakingPercent = regenerativeBrakingPercent
        self.powerTractionPercent = powerTractionPercent
        self.brakingTractionPercent = brakingTractionPercent
    }
}

public enum BikeDeclaredPowerTier: String, Codable, CaseIterable, Equatable, Sendable {
    case standard
    case alpha
}

public enum BikeAlphaEvidence: String, Codable, CaseIterable, Hashable, Sendable {
    case powerAboveStandard
    case tractionControlConfigured
}

public enum BikeDetectedPowerTier: Equatable, Sendable {
    case standardBaseline
    case alpha(evidence: Set<BikeAlphaEvidence>)

    public var alphaEvidence: Set<BikeAlphaEvidence> {
        guard case .alpha(let evidence) = self else { return [] }
        return evidence
    }
}
