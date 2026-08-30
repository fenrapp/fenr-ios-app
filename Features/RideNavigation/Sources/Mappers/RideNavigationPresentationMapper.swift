import Foundation
import RideNavigationDomain
import SettingsDomain

public struct RideNavigationPresentationMapper: Sendable {
    private let locale: Locale

    public init(locale: Locale) {
        self.locale = locale
    }

    func speed(kilometersPerHour: Double?, measurementSystem: MeasurementSystem) -> (String, String) {
        guard let kilometersPerHour, kilometersPerHour.isFinite else { return ("--", "km/h") }
        if measurementSystem.resolved(for: locale) == .us {
            return (String(Int((kilometersPerHour * Constants.milesPerKilometer).rounded())), "mph")
        }
        return (String(Int(kilometersPerHour.rounded())), "km/h")
    }

    func distance(meters: Double, measurementSystem: MeasurementSystem) -> String {
        guard meters.isFinite, meters >= .zero else { return "-- km" }
        if measurementSystem.resolved(for: locale) == .us {
            return String(format: "%.1f mi", meters / Constants.metersPerMile)
        }
        return String(format: "%.1f km", meters / Constants.metersPerKilometer)
    }

    func elapsed(_ seconds: TimeInterval) -> String {
        let value = max(Int(seconds.rounded(.down)), .zero)
        let hours = value / 3_600
        let minutes = (value % 3_600) / 60
        let remainingSeconds = value % 60
        return hours > .zero
            ? String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
            : String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    func routeDetail(_ route: RideRoute, measurementSystem: MeasurementSystem) -> String {
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
            route.containsTolls ? "Tolls" : nil,
            route.containsHighways ? "Highways" : nil
        ].compactMap { $0 }
        let noticeText = notices.isEmpty ? "" : " · " + notices.joined(separator: " · ")
        return RideNavigationRoadRouteOption(
            id: index,
            title: index == .zero ? "Recommended" : "Alternative \(index + 1)",
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

    private func travelTime(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(Int((seconds / 60).rounded()), 1)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > .zero, minutes > .zero { return "\(hours) hr \(minutes) min" }
        if hours > .zero { return "\(hours) hr" }
        return "\(minutes) min"
    }

    private enum Constants {
        static let milesPerKilometer = 0.621_371
        static let metersPerMile = 1_609.344
        static let metersPerKilometer = 1_000.0
    }
}
