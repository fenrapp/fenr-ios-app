import Foundation

public enum MeasurementSystem: String, Codable, CaseIterable, Sendable {
    case system
    case metric
    case imperial

    public func resolved(for locale: Locale = .autoupdatingCurrent) -> Locale.MeasurementSystem {
        switch self {
        case .system: locale.measurementSystem
        case .metric: .metric
        case .imperial: .us
        }
    }
}
