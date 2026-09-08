import Foundation
import RideNavigationDomain
import SettingsDomain

public struct RideNavigationPresentationMapper: Sendable {
    private let locale: Locale
    private let minuteSecondStyle: Duration.TimeFormatStyle
    private let hourMinuteSecondStyle: Duration.TimeFormatStyle
    private let travelTimeStyle: Duration.UnitsFormatStyle

    public init(locale: Locale) {
        self.locale = locale
        minuteSecondStyle = Duration.TimeFormatStyle(
            pattern: .minuteSecond(padMinuteToLength: 2)
        ).locale(locale)
        hourMinuteSecondStyle = Duration.TimeFormatStyle(
            pattern: .hourMinuteSecond(padHourToLength: 1, fractionalSecondsLength: 0)
        ).locale(locale)
        travelTimeStyle = Duration.UnitsFormatStyle(
            allowedUnits: [.hours, .minutes],
            width: .abbreviated,
            maximumUnitCount: 2
        ).locale(locale)
    }

    func speed(kilometersPerHour: Double?, measurementSystem: MeasurementSystem) -> (String, String) {
        guard let kilometersPerHour, kilometersPerHour.isFinite else { return ("--", "km/h") }
        let metric = Measurement(value: kilometersPerHour, unit: UnitSpeed.kilometersPerHour)
        let measurement = measurementSystem.resolved(for: locale) == .us
            ? metric.converted(to: .milesPerHour)
            : metric
        return (format(measurement.value, fractionDigits: 0), measurement.unit.symbol)
    }

    func distance(meters: Double, measurementSystem: MeasurementSystem) -> String {
        guard meters.isFinite, meters >= .zero else { return "-- km" }
        let metric = Measurement(value: meters, unit: UnitLength.meters)
        let measurement = measurementSystem.resolved(for: locale) == .us
            ? metric.converted(to: .miles)
            : metric.converted(to: .kilometers)
        return "\(format(measurement.value, fractionDigits: 1)) \(measurement.unit.symbol)"
    }

    func elapsed(_ seconds: TimeInterval) -> String {
        let value = max(Int(seconds.rounded(.down)), .zero)
        let duration = Duration.seconds(value)
        return duration.formatted(value >= Constants.secondsPerHour ? hourMinuteSecondStyle : minuteSecondStyle)
    }

    func altitude(
        meters: Double?,
        verticalAccuracyMeters: Double?,
        measurementSystem: MeasurementSystem
    ) -> (String, String)? {
        guard let meters,
              let verticalAccuracyMeters,
              meters.isFinite,
              verticalAccuracyMeters.isFinite,
              verticalAccuracyMeters >= .zero else { return nil }
        let metric = Measurement(value: meters, unit: UnitLength.meters)
        let measurement = measurementSystem.resolved(for: locale) == .us
            ? metric.converted(to: .feet)
            : metric
        return (format(measurement.value, fractionDigits: 0), measurement.unit.symbol)
    }

    func progress(_ fraction: Double?) -> String? {
        guard let fraction, fraction.isFinite else { return nil }
        return min(max(fraction, .zero), 1).formatted(
            .percent.locale(locale).precision(.fractionLength(0))
        )
    }

    func routeDetail(_ route: RideRouteSummary, measurementSystem: MeasurementSystem) -> String {
        let routeDistance = distance(
            meters: route.distanceMeters,
            measurementSystem: measurementSystem
        )
        let updatedAt = route.updatedAt.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale)
        )
        return "\(routeDistance) · \(updatedAt)"
    }

    func roadRouteOption(
        _ route: RoadNavigationRoute,
        index: Int,
        isSelected: Bool,
        measurementSystem: MeasurementSystem
    ) -> RideNavigationRoadRouteOption {
        let notices = [
            route.containsTolls ? String(localized: .rideNavigationRouteTolls) : nil,
            route.containsHighways ? String(localized: .rideNavigationRouteHighways) : nil
        ].compactMap { $0 }
        let noticeText = notices.isEmpty ? "" : " · " + notices.joined(separator: " · ")
        return RideNavigationRoadRouteOption(
            id: index,
            title: index == .zero
                ? String(localized: .rideNavigationRouteRecommended)
                : String(localized: .rideNavigationRouteAlternative(index + 1)),
            detail: "\(travelTime(route.expectedTravelTime)) · "
                + distance(meters: route.distanceMeters, measurementSystem: measurementSystem)
                + noticeText,
            isSelected: isSelected
        )
    }

    func trailExitPreview(
        _ exit: TrailExitRoute,
        measurementSystem: MeasurementSystem
    ) -> RideNavigationTrailExitPreview {
        RideNavigationTrailExitPreview(
            title: exit.destination.name,
            detail: "\(travelTime(exit.route.expectedTravelTime)) · "
                + distance(meters: exit.route.distanceMeters, measurementSystem: measurementSystem)
        )
    }

    func forkGuidance(
        routeState: RideRouteGuidanceRouteState?,
        decision: RideRouteGuidanceDecision?,
        measurementSystem: MeasurementSystem
    ) -> RideNavigationForkGuidance? {
        if routeState == .wrongFork {
            return RideNavigationForkGuidance(
                instructionText: String(localized: .rideNavigationWrongFork),
                distanceText: String(localized: .rideNavigationReturnToTrack),
                systemImage: "arrow.uturn.backward",
                emphasis: .warning
            )
        }
        guard let decision else { return nil }
        let instruction: String
        let systemImage: String
        switch decision.direction {
        case .left:
            instruction = String(localized: .rideNavigationKeepLeftUppercase)
            systemImage = "arrow.turn.up.left"
        case .right:
            instruction = String(localized: .rideNavigationKeepRightUppercase)
            systemImage = "arrow.turn.up.right"
        case .straight:
            instruction = String(localized: .rideNavigationContinueStraightUppercase)
            systemImage = "arrow.up"
        }
        return RideNavigationForkGuidance(
            instructionText: instruction,
            distanceText: distance(
                meters: decision.distanceMeters,
                measurementSystem: measurementSystem
            ),
            systemImage: systemImage
        )
    }

    private func travelTime(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(Int((seconds / 60).rounded()), 1)
        return Duration.seconds(totalMinutes * 60).formatted(travelTimeStyle)
    }

    private func format(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(
            .number.locale(locale).precision(.fractionLength(fractionDigits))
        )
    }

    private enum Constants {
        static let secondsPerHour = 3_600
    }
}
