import Foundation

public enum BikeEmulatorScenario: String, CaseIterable, Equatable, Sendable, Identifiable {
    case riding
    case charging
    case cellAnomaly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .riding: "Riding"
        case .charging: "Normal charging"
        case .cellAnomaly: "Cell anomaly"
        }
    }
}
