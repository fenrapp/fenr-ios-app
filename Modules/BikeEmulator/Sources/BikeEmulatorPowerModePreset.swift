import BikeDomain

public enum BikeEmulatorPowerModePreset: String, CaseIterable, Equatable, Sendable, Identifiable {
    case standard
    case alpha
    case claimedAlpha
    case mismatch
    case partial
    case failure

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standard: "Standard 60"
        case .alpha: "Alpha 80"
        case .claimedAlpha: "Claimed Alpha"
        case .mismatch: "Tier mismatch"
        case .partial: "Partial data"
        case .failure: "Read failure"
        }
    }

    public var declaredTier: BikeDeclaredPowerTier {
        switch self {
        case .alpha, .claimedAlpha: .alpha
        case .standard, .mismatch, .partial, .failure: .standard
        }
    }
}
