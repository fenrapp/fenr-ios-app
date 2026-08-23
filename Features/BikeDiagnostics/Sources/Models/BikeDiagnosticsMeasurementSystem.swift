import Foundation
import SettingsDomain

public enum BikeDiagnosticsMeasurementSystem: Sendable, Equatable {
    case metric
    case imperial

    public init(locale: Locale) {
        switch locale.measurementSystem {
        case .metric:
            self = .metric
        default:
            self = .imperial
        }
    }

    public init(measurementSystem: MeasurementSystem, locale: Locale) {
        switch measurementSystem.resolved(for: locale) {
        case .metric: self = .metric
        default: self = .imperial
        }
    }
}
