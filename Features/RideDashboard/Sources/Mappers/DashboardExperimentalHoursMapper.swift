import BikeDomain
import Foundation

public struct DashboardExperimentalHoursMapper: Sendable {
    public init() {}

    static func freshCounter(in telemetry: BikeTelemetry) -> BikeUsageCounter? {
        guard let counter = telemetry.experimentalUsageCounter, let updatedAt = telemetry.lastUpdated else {
            return nil
        }
        let age = updatedAt.timeIntervalSince(counter.sampledAt)
        return age >= .zero && age <= Constants.maximumSampleAge ? counter : nil
    }

    func map(_ telemetry: BikeTelemetry, hasTelemetry: Bool) -> DashboardExperimentalHoursViewData? {
        guard hasTelemetry, let counter = Self.freshCounter(in: telemetry) else { return nil }
        // The seconds scale is provisional until the counter's behavior is verified.
        let value = String(counter.rawValue / Constants.assumedUnitsPerHour)
        return .init(
            valueText: rideDashboardLocalized(.rideDashboardExperimentalHoursValue(value)),
            accessibilityLabel: rideDashboardLocalized(.rideDashboardExperimentalHoursAccessibility(value)),
            rawCounterText: String(counter.rawValue)
        )
    }

    private enum Constants {
        static let assumedUnitsPerHour: UInt32 = 3_600
        static let maximumSampleAge: TimeInterval = 30
    }
}
