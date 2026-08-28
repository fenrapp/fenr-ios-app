import EnvironmentDomain
import Foundation

public struct VehicleMotionEstimator: Sendable {
    private let now: @Sendable () -> Date
    private let maximumSampleAge: TimeInterval
    private let minimumGPSCourseSpeedKilometersPerHour: Double
    private let maximumGPSCourseAccuracyDegrees: Double
    private let smoothingFactor: Double
    private var filteredRollDegrees: Double?
    private var filteredPitchDegrees: Double?
    private var filteredHeadingDegrees: Double?
    private var rollSamples: [Double] = []
    private var pitchSamples: [Double] = []

    public init(
        now: @escaping @Sendable () -> Date,
        maximumSampleAge: TimeInterval,
        minimumGPSCourseSpeedKilometersPerHour: Double,
        maximumGPSCourseAccuracyDegrees: Double,
        smoothingFactor: Double
    ) {
        self.now = now
        self.maximumSampleAge = maximumSampleAge
        self.minimumGPSCourseSpeedKilometersPerHour = minimumGPSCourseSpeedKilometersPerHour
        self.maximumGPSCourseAccuracyDegrees = maximumGPSCourseAccuracyDegrees
        self.smoothingFactor = min(max(smoothingFactor, .zero), 1)
    }

    public mutating func estimate(
        deviceMotion: DeviceMotionSample?,
        calibration: VehicleMotionCalibration?,
        location: DeviceSpeedSample?
    ) -> VehicleMotionSnapshot {
        let heading = resolvedHeading(deviceMotion: deviceMotion, location: location)
        let altitude = validAltitude(location)
        let coordinate = validCoordinate(location)
        guard let deviceMotion else {
            resetAngles()
            return .init(
                headingDegrees: heading.value,
                altitudeMeters: altitude,
                coordinate: coordinate,
                headingSource: heading.source,
                availability: .unavailable
            )
        }
        guard isFresh(deviceMotion.observedAt) else {
            resetAngles()
            return .init(
                headingDegrees: heading.value,
                altitudeMeters: altitude,
                coordinate: coordinate,
                headingSource: heading.source,
                availability: .stale,
                observedAt: deviceMotion.observedAt
            )
        }
        guard let calibration else {
            resetAngles()
            return .init(
                headingDegrees: heading.value,
                altitudeMeters: altitude,
                coordinate: coordinate,
                headingSource: heading.source,
                availability: .uncalibrated,
                observedAt: deviceMotion.observedAt
            )
        }

        let relative = calibration.referenceAttitude.inverse.multiplied(by: deviceMotion.attitude).normalized
        let angles = relative.eulerAngles
        let rawRoll = -angles.rollRadians.radiansToDegrees
        let rawPitch = angles.pitchRadians.radiansToDegrees
        let medianRoll = medianFiltered(rawRoll, samples: &rollSamples)
        let medianPitch = medianFiltered(rawPitch, samples: &pitchSamples)
        let roll = filtered(medianRoll, previous: filteredRollDegrees)
        let pitch = filtered(medianPitch, previous: filteredPitchDegrees)
        filteredRollDegrees = roll
        filteredPitchDegrees = pitch
        if let heading = heading.value {
            filteredHeadingDegrees = filteredHeading(heading)
        } else {
            filteredHeadingDegrees = nil
        }
        return .init(
            rollDegrees: roll,
            pitchDegrees: pitch,
            headingDegrees: filteredHeadingDegrees,
            altitudeMeters: altitude,
            coordinate: coordinate,
            headingSource: heading.source,
            availability: .available,
            observedAt: deviceMotion.observedAt
        )
    }

    public mutating func reset() {
        resetAngles()
        filteredHeadingDegrees = nil
    }
}

private extension VehicleMotionEstimator {
    func isFresh(_ date: Date) -> Bool {
        let age = now().timeIntervalSince(date)
        return age >= .zero && age <= maximumSampleAge
    }

    mutating func resetAngles() {
        filteredRollDegrees = nil
        filteredPitchDegrees = nil
        rollSamples.removeAll(keepingCapacity: true)
        pitchSamples.removeAll(keepingCapacity: true)
    }

    func filtered(_ value: Double, previous: Double?) -> Double {
        guard value.isFinite else { return previous ?? .zero }
        guard let previous else { return value }
        return previous + (value - previous) * smoothingFactor
    }

    func medianFiltered(_ value: Double, samples: inout [Double]) -> Double {
        guard value.isFinite else { return samples.last ?? .zero }
        samples.append(value)
        if samples.count > Constants.medianWindowSize {
            samples.removeFirst(samples.count - Constants.medianWindowSize)
        }
        let sorted = samples.sorted()
        return sorted[sorted.count / 2]
    }

    mutating func filteredHeading(_ value: Double) -> Double {
        let normalized = value.normalizedDegrees
        guard let previous = filteredHeadingDegrees else { return normalized }
        let delta = (normalized - previous + 540).truncatingRemainder(dividingBy: 360) - 180
        return (previous + delta * smoothingFactor).normalizedDegrees
    }

    func resolvedHeading(
        deviceMotion: DeviceMotionSample?,
        location: DeviceSpeedSample?
    ) -> (value: Double?, source: VehicleMotionHeadingSource) {
        if let location,
           isFresh(location.observedAt),
           location.kilometersPerHour >= minimumGPSCourseSpeedKilometersPerHour,
           let course = location.courseDegrees,
           course.isFinite,
           let accuracy = location.courseAccuracyDegrees,
           accuracy.isFinite,
           accuracy <= maximumGPSCourseAccuracyDegrees {
            return (course.normalizedDegrees, .gpsCourse)
        }
        if let deviceMotion,
           isFresh(deviceMotion.observedAt),
           [.medium, .high].contains(deviceMotion.magneticAccuracy),
           let heading = deviceMotion.magneticHeadingDegrees,
           heading.isFinite {
            return (heading.normalizedDegrees, .magnetic)
        }
        return (nil, .unavailable)
    }

    func validAltitude(_ location: DeviceSpeedSample?) -> Double? {
        guard let location,
              isFresh(location.observedAt),
              let altitude = location.altitudeMeters,
              altitude.isFinite,
              let accuracy = location.verticalAccuracyMeters,
              accuracy.isFinite,
              accuracy >= .zero else { return nil }
        return altitude
    }

    func validCoordinate(_ location: DeviceSpeedSample?) -> GeographicCoordinate? {
        guard let location,
              isFresh(location.observedAt) else { return nil }
        return location.coordinate
    }
}

private enum Constants {
    static let medianWindowSize = 5
}

private extension MotionQuaternion {
    var normalized: Self {
        let magnitude = sqrt(
            xComponent * xComponent + yComponent * yComponent
                + zComponent * zComponent + scalarComponent * scalarComponent
        )
        guard magnitude.isFinite, magnitude > .zero else {
            return .init(xComponent: .zero, yComponent: .zero, zComponent: .zero, scalarComponent: 1)
        }
        return .init(
            xComponent: xComponent / magnitude,
            yComponent: yComponent / magnitude,
            zComponent: zComponent / magnitude,
            scalarComponent: scalarComponent / magnitude
        )
    }

    var inverse: Self {
        let normalized = normalized
        return .init(
            xComponent: -normalized.xComponent,
            yComponent: -normalized.yComponent,
            zComponent: -normalized.zComponent,
            scalarComponent: normalized.scalarComponent
        )
    }

    func multiplied(by other: Self) -> Self {
        .init(
            xComponent: scalarComponent * other.xComponent + xComponent * other.scalarComponent
                + yComponent * other.zComponent - zComponent * other.yComponent,
            yComponent: scalarComponent * other.yComponent - xComponent * other.zComponent
                + yComponent * other.scalarComponent + zComponent * other.xComponent,
            zComponent: scalarComponent * other.zComponent + xComponent * other.yComponent
                - yComponent * other.xComponent + zComponent * other.scalarComponent,
            scalarComponent: scalarComponent * other.scalarComponent - xComponent * other.xComponent
                - yComponent * other.yComponent - zComponent * other.zComponent
        )
    }

    var eulerAngles: MotionEulerAngles {
        let value = normalized
        let pitchRadians = atan2(
            2 * (value.scalarComponent * value.xComponent + value.yComponent * value.zComponent),
            1 - 2 * (value.xComponent * value.xComponent + value.yComponent * value.yComponent)
        )
        let rollRadians = atan2(
            2 * (value.scalarComponent * value.zComponent + value.xComponent * value.yComponent),
            1 - 2 * (value.yComponent * value.yComponent + value.zComponent * value.zComponent)
        )
        return .init(
            pitchRadians: pitchRadians,
            rollRadians: rollRadians
        )
    }
}

private struct MotionEulerAngles {
    let pitchRadians: Double
    let rollRadians: Double
}

private extension Double {
    var radiansToDegrees: Double { self * 180 / .pi }

    var normalizedDegrees: Double {
        let value = truncatingRemainder(dividingBy: 360)
        return value >= .zero ? value : value + 360
    }
}
