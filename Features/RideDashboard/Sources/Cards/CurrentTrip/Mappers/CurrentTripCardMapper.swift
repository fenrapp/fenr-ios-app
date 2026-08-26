import Foundation
import RideSessionDomain
import SettingsDomain

public struct CurrentTripCardMapper: Sendable {
    private let makeMeasurementMapper: @Sendable (MeasurementSystem) -> RideDashboardMeasurementMapper
    private let durationFormatStyle: Duration.TimeFormatStyle
    private let speedSourceIndicatorMapper: DashboardSpeedSourceIndicatorMapper

    public init(
        makeMeasurementMapper: @escaping @Sendable (MeasurementSystem) -> RideDashboardMeasurementMapper,
        durationFormatStyle: Duration.TimeFormatStyle,
        speedSourceIndicatorMapper: DashboardSpeedSourceIndicatorMapper
    ) {
        self.makeMeasurementMapper = makeMeasurementMapper
        self.durationFormatStyle = durationFormatStyle
        self.speedSourceIndicatorMapper = speedSourceIndicatorMapper
    }

    public func map(
        trip: RideTrip?,
        measurementSystem: MeasurementSystem,
        speedSource: SpeedSource = .motorcycle,
        isGPSAvailable: Bool = true
    ) -> DashboardCurrentTripViewData {
        let sourceIndicator = speedSourceIndicatorMapper.map(
            speedSource,
            isGPSAvailable: isGPSAvailable
        )
        guard let trip else {
            return .init(
                speedSourceIndicator: sourceIndicator,
                accessibilityLabel: readyAccessibilityLabel(sourceIndicator: sourceIndicator)
            )
        }
        let measurementMapper = makeMeasurementMapper(measurementSystem)
        let distance = measurementMapper.distance(kilometers: trip.distanceKilometers)
        let averageSpeed = measurementMapper.speed(
            kilometersPerHour: trip.averageSpeedKilometersPerHour
        )
        let maximumSpeed = measurementMapper.speed(
            kilometersPerHour: trip.maximumSpeedKilometersPerHour
        )
        let durationText = Duration.seconds(trip.elapsedSeconds).formatted(durationFormatStyle)
        return .init(
            durationText: durationText,
            statusText: trip.isPaused ? "PAUSED" : "IN PROGRESS",
            distance: metric(
                label: "DISTANCE",
                measurement: distance,
                fractionDigits: 1,
                systemImage: "location",
                mapper: measurementMapper
            ),
            averageSpeed: metric(
                label: "AVERAGE",
                measurement: averageSpeed,
                fractionDigits: 0,
                systemImage: "speedometer",
                mapper: measurementMapper
            ),
            maximumSpeed: metric(
                label: "MAX SPEED",
                measurement: maximumSpeed,
                fractionDigits: 0,
                systemImage: "arrow.up.right",
                mapper: measurementMapper
            ),
            speedSourceIndicator: sourceIndicator,
            isActive: true,
            isPaused: trip.isPaused,
            accessibilityLabel: "Current trip\(trip.isPaused ? ", paused" : ""). "
                + "Duration \(durationText). "
                + "Distance \(distance.value) \(distance.unit). "
                + "Average speed \(averageSpeed.value) \(averageSpeed.unit). "
                + "Maximum speed \(maximumSpeed.value) \(maximumSpeed.unit)."
                + sourceAccessibility(sourceIndicator)
        )
    }

    private func readyAccessibilityLabel(
        sourceIndicator: DashboardSpeedSourceIndicatorViewData?
    ) -> String {
        "Current trip has not started" + sourceAccessibility(sourceIndicator)
    }

    private func sourceAccessibility(
        _ sourceIndicator: DashboardSpeedSourceIndicatorViewData?
    ) -> String {
        sourceIndicator.map { " \($0.text) speed source." } ?? ""
    }

    private func metric(
        label: String,
        measurement: RideDashboardMeasurement,
        fractionDigits: Int,
        systemImage: String,
        mapper: RideDashboardMeasurementMapper
    ) -> DashboardCurrentTripViewData.Metric {
        .init(
            label: label,
            valueText: mapper.number(measurement.value, fractionDigits: fractionDigits),
            unit: measurement.unit,
            systemImage: systemImage
        )
    }
}
