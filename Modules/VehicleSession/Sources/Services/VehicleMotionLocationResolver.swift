import EnvironmentDomain
import Foundation

struct VehicleMotionLocationContext {
    let heading: Double?
    let headingSource: VehicleMotionHeadingSource
    let altitude: Double?
    let coordinate: GeographicCoordinate?
}

public struct VehicleMotionLocationResolver: Sendable {
    private let now: @Sendable () -> Date
    private let maximumSampleAge: TimeInterval
    private let minimumCourseSpeedKilometersPerHour: Double
    private let maximumCourseAccuracyDegrees: Double
    private var filteredHeadingDegrees: Double?

    public init(
        now: @escaping @Sendable () -> Date,
        maximumSampleAge: TimeInterval,
        minimumCourseSpeedKilometersPerHour: Double,
        maximumCourseAccuracyDegrees: Double
    ) {
        self.now = now
        self.maximumSampleAge = maximumSampleAge
        self.minimumCourseSpeedKilometersPerHour = minimumCourseSpeedKilometersPerHour
        self.maximumCourseAccuracyDegrees = maximumCourseAccuracyDegrees
    }

    mutating func resolve(_ location: DeviceSpeedSample?) -> VehicleMotionLocationContext {
        if let heading = validHeading(location) {
            filteredHeadingDegrees = filteredHeading(heading)
        } else {
            filteredHeadingDegrees = nil
        }
        return .init(
            heading: filteredHeadingDegrees,
            headingSource: filteredHeadingDegrees == nil ? .unavailable : .gpsCourse,
            altitude: validAltitude(location),
            coordinate: validCoordinate(location)
        )
    }

    public mutating func reset() {
        filteredHeadingDegrees = nil
    }

    private func validHeading(_ location: DeviceSpeedSample?) -> Double? {
        guard let location,
              isFresh(location.observedAt),
              location.kilometersPerHour >= minimumCourseSpeedKilometersPerHour,
              let course = location.courseDegrees,
              course.isFinite,
              let accuracy = location.courseAccuracyDegrees,
              accuracy.isFinite,
              accuracy <= maximumCourseAccuracyDegrees else { return nil }
        return course.normalizedDegrees
    }

    private mutating func filteredHeading(_ value: Double) -> Double {
        let normalized = value.normalizedDegrees
        guard let previous = filteredHeadingDegrees else { return normalized }
        let delta = (normalized - previous + 540).truncatingRemainder(dividingBy: 360) - 180
        return (previous + delta * Constants.headingSmoothingFactor).normalizedDegrees
    }

    private func validAltitude(_ location: DeviceSpeedSample?) -> Double? {
        guard let location,
              isFresh(location.observedAt),
              let altitude = location.altitudeMeters,
              altitude.isFinite,
              let accuracy = location.verticalAccuracyMeters,
              accuracy.isFinite,
              accuracy >= .zero else { return nil }
        return altitude
    }

    private func validCoordinate(_ location: DeviceSpeedSample?) -> GeographicCoordinate? {
        guard let location, isFresh(location.observedAt) else { return nil }
        return location.coordinate
    }

    private func isFresh(_ date: Date) -> Bool {
        let age = now().timeIntervalSince(date)
        return age >= .zero && age <= maximumSampleAge
    }

    private enum Constants {
        static let headingSmoothingFactor = 0.18
    }
}

private extension Double {
    var normalizedDegrees: Double {
        let value = truncatingRemainder(dividingBy: 360)
        return value >= .zero ? value : value + 360
    }
}
