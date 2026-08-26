import Foundation
import RideSessionDomain
import SettingsDomain

public struct TripStatisticsCardMapper: Sendable {
    private let makeMeasurementMapper: @Sendable (MeasurementSystem) -> RideDashboardMeasurementMapper
    private let durationFormatStyle: Duration.TimeFormatStyle

    public init(
        makeMeasurementMapper: @escaping @Sendable (MeasurementSystem) -> RideDashboardMeasurementMapper,
        durationFormatStyle: Duration.TimeFormatStyle
    ) {
        self.makeMeasurementMapper = makeMeasurementMapper
        self.durationFormatStyle = durationFormatStyle
    }

    public func map(
        _ statistics: RideTripStatistics,
        measurementSystem: MeasurementSystem
    ) -> DashboardTripStatisticsViewData {
        let measurementMapper = makeMeasurementMapper(measurementSystem)
        let distance = measurementMapper.distance(
            kilometers: statistics.totalDistanceKilometers
        )
        let averageSpeed = measurementMapper.speed(
            kilometersPerHour: statistics.averageSpeedKilometersPerHour
        )
        let maximumSpeed = measurementMapper.speed(
            kilometersPerHour: statistics.maximumSpeedKilometersPerHour
        )
        let durationText = Duration.seconds(statistics.totalElapsedSeconds)
            .formatted(durationFormatStyle)
        let tripLabel = statistics.tripCount == 1 ? "1 SAVED TRIP" : "\(statistics.tripCount) SAVED TRIPS"

        return DashboardTripStatisticsViewData(
            statusText: statistics.tripCount == .zero ? "NO SAVED TRIPS" : tripLabel,
            totalDistance: .init(
                label: "TOTAL DISTANCE",
                valueText: measurementMapper.number(distance.value, fractionDigits: 1),
                unit: distance.unit
            ),
            totalDuration: .init(label: "RIDE TIME", valueText: durationText),
            averageSpeed: .init(
                label: "AVERAGE",
                valueText: measurementMapper.number(averageSpeed.value, fractionDigits: .zero),
                unit: averageSpeed.unit
            ),
            maximumSpeed: .init(
                label: "MAX SPEED",
                valueText: measurementMapper.number(maximumSpeed.value, fractionDigits: .zero),
                unit: maximumSpeed.unit
            ),
            accessibilityLabel: "Ride statistics. \(tripLabel). "
                + "Total distance \(distance.value) \(distance.unit). "
                + "Ride time \(durationText). "
                + "Average speed \(averageSpeed.value) \(averageSpeed.unit). "
                + "Maximum speed \(maximumSpeed.value) \(maximumSpeed.unit)."
        )
    }
}
