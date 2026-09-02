import Foundation
import RideSession
import SettingsDomain
import VehicleSession

public struct RideDynamicsCardMapper: Sendable {
    private let locale: Locale

    public init(locale: Locale) {
        self.locale = locale
    }

    public func map(_ snapshot: RideSessionSnapshot) -> DashboardRideDynamicsViewData {
        let motion = snapshot.motion
        let trip = snapshot.trip
        let roll = valid(motion.rollDegrees) ?? .zero
        let pitch = valid(motion.pitchDegrees) ?? .zero
        let resolvedHeading = valid(motion.headingDegrees)?.normalizedDegrees
        let heading = resolvedHeading ?? .zero
        let coordinate = motion.coordinate
        return .init(
            status: status(motion.availability),
            leanDegrees: roll,
            leanText: angleText(motion.rollDegrees),
            leanDirectionText: direction(
                value: roll,
                negative: rideDashboardLocalized(.rideDashboardDynamicsDirectionLeft),
                positive: rideDashboardLocalized(.rideDashboardDynamicsDirectionRight)
            ),
            maximumLeftLeanText: angleText(trip?.maximumLeftLeanDegrees),
            maximumRightLeanText: angleText(trip?.maximumRightLeanDegrees),
            pitchDegrees: pitch,
            pitchText: angleText(motion.pitchDegrees),
            pitchDirectionText: direction(
                value: pitch,
                negative: rideDashboardLocalized(.rideDashboardDynamicsDirectionDown),
                positive: rideDashboardLocalized(.rideDashboardDynamicsDirectionUp)
            ),
            maximumUphillPitchText: angleText(trip?.maximumUphillPitchDegrees),
            maximumDownhillPitchText: angleText(trip?.maximumDownhillPitchDegrees),
            headingDegrees: heading,
            isHeadingAvailable: resolvedHeading != nil,
            headingText: resolvedHeading.map(angleText) ?? "—",
            cardinalDirectionText: resolvedHeading.map(cardinalDirection) ?? "—",
            headingSourceText: headingSourceText(motion.headingSource),
            altitudeText: altitudeText(motion.altitudeMeters, system: snapshot.measurementSystem),
            latitudeText: coordinate.map {
                coordinateText(
                    $0.latitudeDegrees,
                    positiveHemisphere: rideDashboardLocalized(.rideDashboardCompassDirectionNorth),
                    negativeHemisphere: rideDashboardLocalized(.rideDashboardCompassDirectionSouth)
                )
            },
            longitudeText: coordinate.map {
                coordinateText(
                    $0.longitudeDegrees,
                    positiveHemisphere: rideDashboardLocalized(.rideDashboardCompassDirectionEast),
                    negativeHemisphere: rideDashboardLocalized(.rideDashboardCompassDirectionWest)
                )
            },
            canCalibrate: snapshot.vehicleIdentity.confirmedVIN != nil
                && motion.availability == .available
        )
    }
}

private extension RideDynamicsCardMapper {
    func valid(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    func angleText(_ value: Double?) -> String {
        guard let value = valid(value) else { return "—" }
        return abs(value).formatted(.number.locale(locale).precision(.fractionLength(0))) + "°"
    }

    func direction(value: Double, negative: String, positive: String) -> String {
        guard abs(value) >= 1 else { return rideDashboardLocalized(.rideDashboardDynamicsDirectionLevel) }
        return value < .zero ? negative : positive
    }

    func status(_ availability: VehicleMotionAvailability) -> DashboardRideDynamicsViewData.Status {
        switch availability {
        case .unavailable: .unavailable
        case .calibrating: .calibrating
        case .zeroing: .zeroing
        case .available: .live
        case .stale: .signalLost
        }
    }

    func headingSourceText(_ source: VehicleMotionHeadingSource) -> String {
        switch source {
        case .unavailable: rideDashboardLocalized(.rideDashboardDynamicsCourseUnavailable)
        case .gpsCourse: rideDashboardLocalized(.rideDashboardDynamicsCourseSourceGPS)
        }
    }

    func cardinalDirection(_ degrees: Double) -> String {
        let directions: [LocalizedStringResource] = [
            .rideDashboardCompassDirectionNorth,
            .rideDashboardCompassDirectionNorthNortheast,
            .rideDashboardCompassDirectionNortheast,
            .rideDashboardCompassDirectionEastNortheast,
            .rideDashboardCompassDirectionEast,
            .rideDashboardCompassDirectionEastSoutheast,
            .rideDashboardCompassDirectionSoutheast,
            .rideDashboardCompassDirectionSouthSoutheast,
            .rideDashboardCompassDirectionSouth,
            .rideDashboardCompassDirectionSouthSouthwest,
            .rideDashboardCompassDirectionSouthwest,
            .rideDashboardCompassDirectionWestSouthwest,
            .rideDashboardCompassDirectionWest,
            .rideDashboardCompassDirectionWestNorthwest,
            .rideDashboardCompassDirectionNorthwest,
            .rideDashboardCompassDirectionNorthNorthwest
        ]
        let index = Int((degrees.normalizedDegrees + 11.25) / 22.5)
            .quotientAndRemainder(dividingBy: directions.count).remainder
        return rideDashboardLocalized(directions[index])
    }

    func altitudeText(_ meters: Double?, system: MeasurementSystem) -> String? {
        guard let meters = valid(meters) else { return nil }
        let usesFeet = system.resolved(for: locale) == .us
        let value = usesFeet ? meters * 3.280_84 : meters
        return value.formatted(.number.locale(locale).precision(.fractionLength(0))) + (usesFeet ? " ft" : " m")
    }

    func coordinateText(
        _ value: Double,
        positiveHemisphere: String,
        negativeHemisphere: String
    ) -> String {
        let totalSeconds = Int((abs(value) * Double(Constants.secondsPerDegree)).rounded())
        let degrees = totalSeconds / Constants.secondsPerDegree
        let remainingSeconds = totalSeconds % Constants.secondsPerDegree
        let minutes = remainingSeconds / Constants.secondsPerMinute
        let seconds = remainingSeconds % Constants.secondsPerMinute
        let hemisphere = value < .zero ? negativeHemisphere : positiveHemisphere
        return "\(degrees)°\(minutes)′\(seconds)″ \(hemisphere)"
    }

    enum Constants {
        static let secondsPerMinute = 60
        static let secondsPerDegree = 3_600
    }
}

private extension Double {
    var normalizedDegrees: Double {
        let value = truncatingRemainder(dividingBy: 360)
        return value >= .zero ? value : value + 360
    }
}
