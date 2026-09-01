import Foundation
import MeasurementPresentation
import RideSessionDomain
import SettingsDomain

extension RideHistoryMapper {
    func row(
        _ trip: RideTrip,
        measurementMapper: VehicleMeasurementMapper,
        measurementSystem: MeasurementSystem
    ) -> RideHistoryViewState.Row {
        let distance = measurementMapper.distance(kilometers: trip.distanceKilometers)
        let usesMiles = measurementSystem.resolved(for: locale) == .us
        let efficiency = trip.efficiencyWattHoursPerKilometer.map {
            $0 * (usesMiles ? Constants.kilometersPerMile : 1)
        }
        let efficiencyText = efficiency.map {
            format($0, fractionDigits: abs($0) < 10 ? 1 : 0) + (usesMiles ? " Wh/mi" : " Wh/km")
        } ?? "Efficiency unavailable"
        let distanceText = distanceText(distance)
        let durationText = formatDuration(trip.elapsedSeconds)
        let dateText = trip.startedAt.formatted(
            .dateTime.locale(locale).month(.abbreviated).day().year()
        )
        let timeText = trip.startedAt.formatted(.dateTime.locale(locale).hour().minute())
        return .init(
            id: trip.id,
            dateText: dateText,
            timeText: timeText,
            distanceText: distanceText,
            durationText: durationText,
            efficiencyText: efficiencyText,
            accessibilityLabel: "Ride on \(dateText) at \(timeText), "
                + "\(distanceText), \(durationText), \(efficiencyText)"
        )
    }

    func metric(
        id: String,
        label: String,
        value: String,
        detail: String? = nil
    ) -> RideHistoryDetailViewState.Metric {
        .init(
            id: id,
            symbolName: metricSymbolName(for: id),
            label: label,
            value: value,
            detail: detail
        )
    }

    func metricSymbolName(for id: String) -> String {
        switch id {
        case "duration": "clock"
        case "averageSpeed": "gauge.with.dots.needle.33percent"
        case "maximumSpeed": "gauge.with.dots.needle.67percent"
        case "used": "bolt.fill"
        case "recovered": "arrow.uturn.backward.circle"
        case "net": "equal.circle"
        case "efficiency": "leaf"
        case "coverage": "waveform.path.ecg"
        case "batteryChange": "battery.50percent"
        case "recoveryShare": "arrow.triangle.2.circlepath"
        case "peakUse": "bolt.badge.clock.fill"
        case "peakRegen": "bolt.trianglebadge.exclamationmark.fill"
        case "leftLean", "rightLean": "angle"
        case "uphillPitch", "downhillPitch": "mountain.2"
        default: "circle"
        }
    }

    func powerMetric(
        id: String,
        label: String,
        watts: Double,
        measurementMapper: VehicleMeasurementMapper
    ) -> RideHistoryDetailViewState.Metric? {
        guard watts.isFinite, watts > .zero else { return nil }
        let power = measurementMapper.power(watts: watts)
        return metric(
            id: id,
            label: label,
            value: format(power.value, fractionDigits: 1) + " \(power.unit)"
        )
    }

    func makeMeasurementMapper(_ system: MeasurementSystem) -> VehicleMeasurementMapper {
        measurementMapperFactory.make(measurementSystem: system, locale: locale)
    }

    func timeRange(_ trip: RideTrip) -> String {
        let start = trip.startedAt.formatted(.dateTime.locale(locale).hour().minute())
        guard let end = trip.endedAt else { return start }
        return start + "–" + end.formatted(.dateTime.locale(locale).hour().minute())
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(seconds, .zero)).formatted(durationStyle)
    }

    func distanceText(_ measurement: VehicleMeasurement) -> String {
        format(measurement.value, fractionDigits: measurement.value < 10 ? 1 : 0) + " \(measurement.unit)"
    }

    func speedText(_ measurement: VehicleMeasurement) -> String {
        format(measurement.value, fractionDigits: 0) + " \(measurement.unit)"
    }

    func formatEnergy(_ wattHours: Double) -> String {
        guard wattHours.isFinite else { return "—" }
        if abs(wattHours) >= 1_000 {
            return format(wattHours / 1_000, fractionDigits: 1) + " kWh"
        }
        return format(wattHours, fractionDigits: 0) + " Wh"
    }

    func format(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(
            .number.locale(locale).precision(.fractionLength(fractionDigits))
        )
    }

    enum Constants {
        static let kilometersPerMile = 1.609_344
        static let comparisonLimit = 10
        static let minimumComparisonSamples = 3
        static let minimumChartPoints = 2
        static let equalComparisonThreshold = 0.5
    }
}
