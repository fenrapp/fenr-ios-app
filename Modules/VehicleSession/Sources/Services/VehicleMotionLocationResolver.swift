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
    private let maximumPositionSampleAge: TimeInterval
    private let minimumCourseSpeedKilometersPerHour: Double
    private let maximumCourseAccuracyDegrees: Double
    private var filteredHeadingDegrees: Double?
    private var previousSource = VehicleMotionHeadingSource.unavailable

    public init(
        now: @escaping @Sendable () -> Date,
        maximumSampleAge: TimeInterval,
        minimumCourseSpeedKilometersPerHour: Double,
        maximumCourseAccuracyDegrees: Double,
        maximumPositionSampleAge: TimeInterval? = nil
    ) {
        self.now = now
        self.maximumSampleAge = maximumSampleAge
        self.maximumPositionSampleAge = maximumPositionSampleAge ?? maximumSampleAge
        self.minimumCourseSpeedKilometersPerHour = minimumCourseSpeedKilometersPerHour
        self.maximumCourseAccuracyDegrees = maximumCourseAccuracyDegrees
    }

    mutating func resolve(
        _ location: DeviceSpeedSample?, compass: DeviceHeadingSample? = nil,
        position: DeviceSpeedSample? = nil
    ) -> VehicleMotionLocationContext {
        let course = validHeading(location)
        let compass = validCompass(compass)
        let source: VehicleMotionHeadingSource = course != nil ? .gpsCourse : (compass != nil ? .compass : .unavailable)
        if source != previousSource { filteredHeadingDegrees = nil }
        previousSource = source
        if let heading = course ?? compass {
            filteredHeadingDegrees = filteredHeading(heading)
        } else {
            filteredHeadingDegrees = nil
        }
        return .init(
            heading: filteredHeadingDegrees,
            headingSource: source,
            altitude: validAltitude(position ?? location),
            coordinate: validCoordinate(position ?? location)
        )
    }

    public mutating func reset() {
        filteredHeadingDegrees = nil
        previousSource = .unavailable
    }

    private func validHeading(_ location: DeviceSpeedSample?) -> Double? {
        guard let location,
              isFresh(location.observedAt),
              location.kilometersPerHour >= minimumCourseSpeedKilometersPerHour,
              let course = location.courseDegrees,
              course.isFinite,
              let accuracy = location.courseAccuracyDegrees,
              accuracy.isFinite,
              accuracy >= .zero,
              accuracy <= maximumCourseAccuracyDegrees else { return nil }
        return course.normalizedDegrees
    }

    func remainingValidity(of sample: DeviceHeadingSample) -> TimeInterval? {
        let age = now().timeIntervalSince(sample.observedAt)
        guard age >= .zero, age < maximumSampleAge else { return nil }
        return maximumSampleAge - age
    }

    private func validCompass(_ sample: DeviceHeadingSample?) -> Double? {
        guard let sample, isFresh(sample.observedAt), sample.degrees.isFinite,
              (0 ..< 360).contains(sample.degrees), sample.accuracyDegrees.isFinite,
              (0 ... maximumCourseAccuracyDegrees).contains(sample.accuracyDegrees) else { return nil }
        return sample.degrees
    }

    private mutating func filteredHeading(_ value: Double) -> Double {
        let normalized = value.normalizedDegrees
        guard let previous = filteredHeadingDegrees else { return normalized }
        let delta = (normalized - previous + 540).truncatingRemainder(dividingBy: 360) - 180
        return (previous + delta * Constants.headingSmoothingFactor).normalizedDegrees
    }

    private func validAltitude(_ location: DeviceSpeedSample?) -> Double? {
        guard let location,
              isPositionFresh(location.observedAt),
              let altitude = location.altitudeMeters,
              altitude.isFinite,
              let accuracy = location.verticalAccuracyMeters,
              accuracy.isFinite,
              accuracy >= .zero else { return nil }
        return altitude
    }

    private func validCoordinate(_ location: DeviceSpeedSample?) -> GeographicCoordinate? {
        guard let location, isPositionFresh(location.observedAt) else { return nil }
        return location.coordinate
    }

    func remainingPositionValidity(of sample: DeviceSpeedSample) -> TimeInterval? {
        guard validCoordinate(sample) != nil || validAltitude(sample) != nil else { return nil }
        return maximumPositionSampleAge - now().timeIntervalSince(sample.observedAt)
    }

    private func isPositionFresh(_ date: Date) -> Bool {
        let age = now().timeIntervalSince(date)
        return age >= .zero && age < maximumPositionSampleAge
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
