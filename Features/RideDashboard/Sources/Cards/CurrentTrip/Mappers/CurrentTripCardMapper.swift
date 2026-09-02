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
            statusText: rideDashboardLocalized(
                trip.isPaused ? .rideDashboardCurrentTripStatusPaused : .rideDashboardCurrentTripStatusInProgress
            ),
            distance: metric(
                label: rideDashboardLocalized(.rideDashboardMetricDistance),
                measurement: distance,
                fractionDigits: 1,
                systemImage: "location",
                mapper: measurementMapper
            ),
            averageSpeed: metric(
                label: rideDashboardLocalized(.rideDashboardMetricAverage),
                measurement: averageSpeed,
                fractionDigits: 0,
                systemImage: "speedometer",
                mapper: measurementMapper
            ),
            maximumSpeed: metric(
                label: rideDashboardLocalized(.rideDashboardMetricMaximumSpeed),
                measurement: maximumSpeed,
                fractionDigits: 0,
                systemImage: "arrow.up.right",
                mapper: measurementMapper
            ),
            speedSourceIndicator: sourceIndicator,
            isActive: true,
            isPaused: trip.isPaused,
            accessibilityLabel: accessibilityLabel(.init(
                isPaused: trip.isPaused,
                durationText: durationText,
                distance: distance,
                averageSpeed: averageSpeed,
                maximumSpeed: maximumSpeed,
                sourceIndicator: sourceIndicator
            ))
        )
    }

    private func accessibilityLabel(_ input: CurrentTripAccessibilityInput) -> String {
        let source = sourceAccessibility(input.sourceIndicator)
        return rideDashboardLocalized(
            input.isPaused
                ? .rideDashboardCurrentTripAccessibilityPaused(
                    input.durationText, String(input.distance.value), input.distance.unit,
                    String(input.averageSpeed.value), input.averageSpeed.unit,
                    String(input.maximumSpeed.value), input.maximumSpeed.unit, source
                )
                : .rideDashboardCurrentTripAccessibility(
                    input.durationText, String(input.distance.value), input.distance.unit,
                    String(input.averageSpeed.value), input.averageSpeed.unit,
                    String(input.maximumSpeed.value), input.maximumSpeed.unit, source
                )
        )
    }

    private func readyAccessibilityLabel(
        sourceIndicator: DashboardSpeedSourceIndicatorViewData?
    ) -> String {
        guard let sourceIndicator else {
            return rideDashboardLocalized(.rideDashboardCurrentTripAccessibilityNotStarted)
        }
        return rideDashboardLocalized(
            .rideDashboardCurrentTripAccessibilityNotStartedWithSource(sourceIndicator.text)
        )
    }

    private func sourceAccessibility(
        _ sourceIndicator: DashboardSpeedSourceIndicatorViewData?
    ) -> String {
        sourceIndicator.map {
            rideDashboardLocalized(.rideDashboardCurrentTripSourceAccessibility($0.text))
        } ?? ""
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

private struct CurrentTripAccessibilityInput {
    let isPaused: Bool
    let durationText: String
    let distance: RideDashboardMeasurement
    let averageSpeed: RideDashboardMeasurement
    let maximumSpeed: RideDashboardMeasurement
    let sourceIndicator: DashboardSpeedSourceIndicatorViewData?
}
