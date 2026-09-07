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
        measurementSystem: MeasurementSystem,
        historyReadFailed: Bool = false,
        hasLoadedHistory: Bool = false
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
        let tripLabel = rideDashboardLocalized(
            .rideDashboardTripStatisticsSavedTrips(statistics.tripCount)
        )

        return DashboardTripStatisticsViewData(
            historyError: historyReadFailed
                ? rideDashboardLocalized(hasLoadedHistory
                    ? .rideDashboardHistoryRefreshError : .rideDashboardHistoryLoadError)
                : nil,
            showsStatistics: hasLoadedHistory || !historyReadFailed,
            statusText: statistics.tripCount == .zero
                ? rideDashboardLocalized(.rideDashboardTripStatisticsStatusNone)
                : tripLabel,
            totalDistance: .init(
                label: rideDashboardLocalized(.rideDashboardMetricTotalDistance),
                valueText: measurementMapper.number(distance.value, fractionDigits: 1),
                unit: distance.unit
            ),
            totalDuration: .init(label: rideDashboardLocalized(.rideDashboardMetricRideTime), valueText: durationText),
            averageSpeed: .init(
                label: rideDashboardLocalized(.rideDashboardMetricAverage),
                valueText: measurementMapper.number(averageSpeed.value, fractionDigits: .zero),
                unit: averageSpeed.unit
            ),
            maximumSpeed: .init(
                label: rideDashboardLocalized(.rideDashboardMetricMaximumSpeed),
                valueText: measurementMapper.number(maximumSpeed.value, fractionDigits: .zero),
                unit: maximumSpeed.unit
            ),
            accessibilityLabel: rideDashboardLocalized(.rideDashboardTripStatisticsAccessibility(
                tripLabel,
                String(distance.value),
                distance.unit,
                durationText,
                String(averageSpeed.value),
                averageSpeed.unit,
                String(maximumSpeed.value),
                maximumSpeed.unit
            ))
        )
    }
}
