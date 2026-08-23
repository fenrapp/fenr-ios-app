import DesignSystem
import SwiftUI

enum DashboardGaugeMode {
    case speed(speed: RideDashboardMeasurement?, maximum: RideDashboardMeasurement)
    case charging(percentage: Int?, targetPercentage: Int?, estimatedTimeRemaining: String?)

    var value: Double {
        switch self {
        case let .speed(speed, _): speed?.value ?? .zero
        case let .charging(percentage, _, _): Double(percentage ?? .zero)
        }
    }

    var maximumValue: Double {
        switch self {
        case let .speed(_, maximum): maximum.value
        case .charging: Constants.maximumPercentage
        }
    }

    var unit: String? {
        switch self {
        case let .speed(speed, maximum): speed?.unit ?? maximum.unit
        case .charging: nil
        }
    }

    var title: String? {
        guard case let .charging(_, _, estimatedTimeRemaining) = self else { return nil }
        return estimatedTimeRemaining.map { "ETA: \($0)" } ?? "CHARGING"
    }

    var isShowingEstimatedTime: Bool {
        guard case let .charging(_, _, estimatedTimeRemaining) = self else { return false }
        return estimatedTimeRemaining != nil
    }

    var targetProgress: Double? {
        guard case let .charging(_, targetPercentage, _) = self else { return nil }
        return targetPercentage.map { min(max(Double($0) / Constants.maximumPercentage, .zero), 1) }
    }

    var showsTicks: Bool {
        if case .speed = self { return true }
        return false
    }

    var progressColor: Color {
        switch self {
        case let .speed(speed, maximum):
            let progress = min(max((speed?.value ?? .zero) / maximum.value, .zero), 1)
            return switch progress {
            case ..<Constants.moderateSpeedProgress: DesignColor.informational
            case ..<Constants.fastSpeedProgress: DesignColor.positive
            default: DesignColor.warning
            }
        case .charging:
            return DesignColor.informational
        }
    }

    var accessibilityLabel: String {
        switch self {
        case let .speed(speed, maximum):
            return "Speed \(format(speed?.value ?? .zero)) \(speed?.unit ?? maximum.unit)"
        case let .charging(percentage, targetPercentage, _):
            let target = targetPercentage.map { " Target \($0) percent" } ?? ""
            return "Charging \(percentage.map { "\($0) percent" } ?? "unavailable").\(target)"
        }
    }

    func displayValue(_ value: Double) -> String {
        format(value)
    }

    private func format(_ value: Double) -> String {
        value.rounded().formatted(.number.precision(.fractionLength(0)))
    }

    private enum Constants {
        static let maximumPercentage = 100.0
        static let moderateSpeedProgress = 0.45
        static let fastSpeedProgress = 0.72
    }
}
