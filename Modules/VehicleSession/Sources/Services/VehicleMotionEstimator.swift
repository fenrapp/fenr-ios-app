import BikeDomain
import EnvironmentDomain
import Foundation

// The complementary filter and its validation helpers intentionally live together.
// swiftlint:disable file_length

public struct VehicleMotionEstimation: Equatable, Sendable {
    public let snapshot: VehicleMotionSnapshot
    public let calibrationToPersist: VehicleMotionCalibration?

    public init(
        snapshot: VehicleMotionSnapshot,
        calibrationToPersist: VehicleMotionCalibration? = nil
    ) {
        self.snapshot = snapshot
        self.calibrationToPersist = calibrationToPersist
    }
}

public struct VehicleMotionEstimator: Sendable {
    private let profile: BikeIMUProfile?
    private let now: @Sendable () -> Date
    private let maximumSampleAge: TimeInterval
    private let maximumLocationSampleAge: TimeInterval
    private let minimumGPSCourseSpeedKilometersPerHour: Double
    private let maximumGPSCourseAccuracyDegrees: Double
    private var filteredRollDegrees: Double?
    private var filteredPitchDegrees: Double?
    private var filteredHeadingDegrees: Double?
    private var previousSampleDate: Date?
    private var stableSamples: [BikeIMUSample] = []
    private var stableWindowStartedAt: Date?
    private var didRefreshBiasThisSession = false
    private var isZeroRequested = false

    public init(
        profile: BikeIMUProfile?,
        now: @escaping @Sendable () -> Date,
        maximumSampleAge: TimeInterval,
        minimumGPSCourseSpeedKilometersPerHour: Double,
        maximumGPSCourseAccuracyDegrees: Double,
        maximumLocationSampleAge: TimeInterval? = nil
    ) {
        self.profile = profile
        self.now = now
        self.maximumSampleAge = maximumSampleAge
        self.maximumLocationSampleAge = maximumLocationSampleAge ?? maximumSampleAge
        self.minimumGPSCourseSpeedKilometersPerHour = minimumGPSCourseSpeedKilometersPerHour
        self.maximumGPSCourseAccuracyDegrees = maximumGPSCourseAccuracyDegrees
    }

    // swiftlint:disable:next function_body_length
    public mutating func estimate(
        imuSample: BikeIMUSample?,
        calibration: VehicleMotionCalibration?,
        vin: String?,
        location: DeviceSpeedSample?,
        bikeSpeedKilometersPerHour: Double?
    ) -> VehicleMotionEstimation {
        let context = locationContext(location)
        guard let profile, isValid(profile) else {
            resetTracking()
            return result(availability: .unavailable, context: context)
        }
        guard let sample = imuSample else {
            resetTracking()
            return result(availability: .unavailable, context: context)
        }
        guard isFresh(sample.observedAt) else {
            resetTracking()
            return result(availability: .stale, observedAt: sample.observedAt, context: context)
        }

        let existingCalibration = valid(calibration, for: profile, vin: vin)
        let stable = isStable(
            sample,
            bikeSpeedKilometersPerHour: bikeSpeedKilometersPerHour,
            calibration: existingCalibration,
            profile: profile
        )
        updateStableWindow(with: sample, isStable: stable)

        let completedWindow = hasCompletedStableWindow(at: sample.observedAt)
        var effectiveCalibration = existingCalibration
        var calibrationToPersist: VehicleMotionCalibration?
        if completedWindow,
           let vin,
           existingCalibration == nil || !didRefreshBiasThisSession || isZeroRequested {
            let bias = medianGyroscopeBias()
            effectiveCalibration = VehicleMotionCalibration(
                vin: vin,
                gyroscopeBiasXRaw: bias.x,
                gyroscopeBiasYRaw: bias.y,
                gyroscopeBiasZRaw: bias.z,
                rollZeroOffsetDegrees: existingCalibration?.rollZeroOffsetDegrees ?? .zero,
                pitchZeroOffsetDegrees: existingCalibration?.pitchZeroOffsetDegrees ?? .zero,
                profileVersion: profile.version,
                calibratedAt: sample.observedAt
            )
            calibrationToPersist = effectiveCalibration
            didRefreshBiasThisSession = true
            clearStableWindow()
        }

        let baseAngles = updateFilter(
            sample: sample,
            calibration: effectiveCalibration,
            profile: profile
        )
        guard var effectiveCalibration else {
            return result(availability: .calibrating, observedAt: sample.observedAt, context: context)
        }
        guard let baseAngles else {
            return result(availability: .unavailable, observedAt: sample.observedAt, context: context)
        }

        if isZeroRequested {
            guard completedWindow else {
                let displayed = applyingOffsets(baseAngles, calibration: effectiveCalibration)
                return result(
                    rollDegrees: displayed.roll,
                    pitchDegrees: displayed.pitch,
                    availability: .zeroing,
                    observedAt: sample.observedAt,
                    context: context
                )
            }
            effectiveCalibration = VehicleMotionCalibration(
                vin: effectiveCalibration.vin,
                gyroscopeBiasXRaw: effectiveCalibration.gyroscopeBiasXRaw,
                gyroscopeBiasYRaw: effectiveCalibration.gyroscopeBiasYRaw,
                gyroscopeBiasZRaw: effectiveCalibration.gyroscopeBiasZRaw,
                rollZeroOffsetDegrees: -baseAngles.roll,
                pitchZeroOffsetDegrees: -baseAngles.pitch,
                profileVersion: profile.version,
                calibratedAt: sample.observedAt
            )
            calibrationToPersist = effectiveCalibration
            isZeroRequested = false
        }

        let displayed = applyingOffsets(baseAngles, calibration: effectiveCalibration)
        guard abs(displayed.roll) <= Constants.maximumLeanDegrees,
              abs(displayed.pitch) <= Constants.maximumPitchDegrees
        else {
            return result(availability: .unavailable, observedAt: sample.observedAt, context: context)
        }
        return result(
            rollDegrees: displayed.roll,
            pitchDegrees: displayed.pitch,
            availability: .available,
            observedAt: sample.observedAt,
            context: context,
            calibrationToPersist: calibrationToPersist
        )
    }

    public mutating func requestZero() {
        isZeroRequested = true
        clearStableWindow()
    }

    public mutating func reset() {
        resetTracking()
        clearStableWindow()
        filteredHeadingDegrees = nil
        didRefreshBiasThisSession = false
        isZeroRequested = false
    }

    func remainingFreshnessDuration(for date: Date) -> Duration? {
        let age = now().timeIntervalSince(date)
        guard age.isFinite, age >= .zero, age < maximumSampleAge else { return nil }
        return .seconds(maximumSampleAge - age)
    }
}

private extension VehicleMotionEstimator {
    struct Angles {
        let roll: Double
        let pitch: Double
    }

    struct LocationContext {
        let heading: Double?
        let headingSource: VehicleMotionHeadingSource
        let altitude: Double?
        let coordinate: GeographicCoordinate?
    }

    mutating func updateFilter(
        sample: BikeIMUSample,
        calibration: VehicleMotionCalibration?,
        profile: BikeIMUProfile
    ) -> Angles? {
        let accelerationAngles = gravityAngles(sample: sample, profile: profile)
        guard let calibration else {
            guard let accelerationAngles else {
                resetTracking()
                return nil
            }
            filteredRollDegrees = accelerationAngles.roll
            filteredPitchDegrees = accelerationAngles.pitch
            previousSampleDate = sample.observedAt
            return accelerationAngles
        }

        let biasCorrected = BikeIMUVector(
            x: sample.gyroscopeRaw.x - calibration.gyroscopeBiasXRaw,
            y: sample.gyroscopeRaw.y - calibration.gyroscopeBiasYRaw,
            z: sample.gyroscopeRaw.z - calibration.gyroscopeBiasZRaw
        )
        let transformedGyroscope = profile.gyroscopeTransform.apply(to: biasCorrected)
        let rates = BikeIMUVector(
            x: transformedGyroscope.x * profile.gyroscopeDegreesPerSecondPerRawUnit.x,
            y: transformedGyroscope.y * profile.gyroscopeDegreesPerSecondPerRawUnit.y,
            z: transformedGyroscope.z * profile.gyroscopeDegreesPerSecondPerRawUnit.z
        )
        guard rates.isFinite else { return nil }
        guard let previousSampleDate,
              let previousRoll = filteredRollDegrees,
              let previousPitch = filteredPitchDegrees
        else {
            guard let accelerationAngles else { return nil }
            filteredRollDegrees = accelerationAngles.roll
            filteredPitchDegrees = accelerationAngles.pitch
            self.previousSampleDate = sample.observedAt
            return accelerationAngles
        }

        let interval = sample.observedAt.timeIntervalSince(previousSampleDate)
        guard interval > .zero else {
            if interval < .zero {
                resetTracking()
            }
            return nil
        }
        guard interval <= Constants.maximumIntegrationInterval else {
            resetTracking()
            guard let accelerationAngles else { return nil }
            filteredRollDegrees = accelerationAngles.roll
            filteredPitchDegrees = accelerationAngles.pitch
            self.previousSampleDate = sample.observedAt
            return accelerationAngles
        }
        var roll = previousRoll + rates.x * interval
        var pitch = previousPitch + rates.y * interval
        if let accelerationAngles {
            roll = Constants.gyroscopeWeight * roll
                + (1 - Constants.gyroscopeWeight) * accelerationAngles.roll
            pitch = Constants.gyroscopeWeight * pitch
                + (1 - Constants.gyroscopeWeight) * accelerationAngles.pitch
        }
        filteredRollDegrees = roll
        filteredPitchDegrees = pitch
        self.previousSampleDate = sample.observedAt
        return .init(roll: roll, pitch: pitch)
    }

    func gravityAngles(sample: BikeIMUSample, profile: BikeIMUProfile) -> Angles? {
        let acceleration = profile.accelerationTransform.apply(to: sample.accelerationRaw)
        let magnitude = acceleration.magnitude
        guard acceleration.isFinite,
              magnitude.isFinite,
              Constants.gravityCorrectionRange.contains(magnitude / profile.oneGRaw)
        else {
            return nil
        }
        return .init(
            roll: atan2(acceleration.y, acceleration.z).radiansToDegrees,
            pitch: atan2(-acceleration.x, hypot(acceleration.y, acceleration.z)).radiansToDegrees
        )
    }

    func applyingOffsets(_ angles: Angles, calibration: VehicleMotionCalibration) -> Angles {
        .init(
            roll: angles.roll + calibration.rollZeroOffsetDegrees,
            pitch: angles.pitch + calibration.pitchZeroOffsetDegrees
        )
    }

    func isStable(
        _ sample: BikeIMUSample,
        bikeSpeedKilometersPerHour: Double?,
        calibration: VehicleMotionCalibration?,
        profile: BikeIMUProfile
    ) -> Bool {
        guard abs(bikeSpeedKilometersPerHour ?? .infinity) <= Constants.maximumStationarySpeed else {
            return false
        }
        let acceleration = profile.accelerationTransform.apply(to: sample.accelerationRaw)
        guard Constants.gravityCorrectionRange.contains(acceleration.magnitude / profile.oneGRaw) else {
            return false
        }
        let biasCorrected = BikeIMUVector(
            x: sample.gyroscopeRaw.x - (calibration?.gyroscopeBiasXRaw ?? .zero),
            y: sample.gyroscopeRaw.y - (calibration?.gyroscopeBiasYRaw ?? .zero),
            z: sample.gyroscopeRaw.z - (calibration?.gyroscopeBiasZRaw ?? .zero)
        )
        let gyroscope = profile.gyroscopeTransform.apply(to: biasCorrected)
        let rates = BikeIMUVector(
            x: gyroscope.x * profile.gyroscopeDegreesPerSecondPerRawUnit.x,
            y: gyroscope.y * profile.gyroscopeDegreesPerSecondPerRawUnit.y,
            z: gyroscope.z * profile.gyroscopeDegreesPerSecondPerRawUnit.z
        )
        return rates.magnitude <= Constants.maximumStationaryGyroDPS
    }

    mutating func updateStableWindow(with sample: BikeIMUSample, isStable: Bool) {
        guard isStable else {
            clearStableWindow()
            return
        }
        if let previousDate = stableSamples.last?.observedAt {
            let interval = sample.observedAt.timeIntervalSince(previousDate)
            if interval <= .zero || interval > Constants.maximumIntegrationInterval {
                clearStableWindow()
            }
        }
        stableWindowStartedAt = stableWindowStartedAt ?? sample.observedAt
        stableSamples.append(sample)
    }

    func hasCompletedStableWindow(at date: Date) -> Bool {
        guard stableSamples.count >= Constants.minimumStableSampleCount,
              let start = stableWindowStartedAt
        else {
            return false
        }
        return date.timeIntervalSince(start) >= Constants.stableWindowDuration
    }

    mutating func clearStableWindow() {
        stableSamples.removeAll(keepingCapacity: true)
        stableWindowStartedAt = nil
    }

    func medianGyroscopeBias() -> BikeIMUVector {
        .init(
            x: median(stableSamples.map(\.gyroscopeRaw.x)),
            y: median(stableSamples.map(\.gyroscopeRaw.y)),
            z: median(stableSamples.map(\.gyroscopeRaw.z))
        )
    }

    func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return .zero }
        let middle = sorted.count / 2
        guard sorted.count.isMultiple(of: 2) else { return sorted[middle] }
        return (sorted[middle - 1] + sorted[middle]) / 2
    }

    func valid(
        _ calibration: VehicleMotionCalibration?,
        for profile: BikeIMUProfile,
        vin: String?
    ) -> VehicleMotionCalibration? {
        guard let calibration,
              calibration.vin == vin,
              calibration.profileVersion == profile.version,
              calibration.gyroscopeBiasXRaw.isFinite,
              calibration.gyroscopeBiasYRaw.isFinite,
              calibration.gyroscopeBiasZRaw.isFinite,
              calibration.rollZeroOffsetDegrees.isFinite,
              calibration.pitchZeroOffsetDegrees.isFinite
        else {
            return nil
        }
        return calibration
    }

    func isValid(_ profile: BikeIMUProfile) -> Bool {
        profile.version > 0
            && profile.oneGRaw.isFinite
            && profile.oneGRaw > .zero
            && profile.accelerationTransform.isBijective
            && profile.gyroscopeTransform.isBijective
            && profile.gyroscopeDegreesPerSecondPerRawUnit.isFinite
            && profile.gyroscopeDegreesPerSecondPerRawUnit.x > .zero
            && profile.gyroscopeDegreesPerSecondPerRawUnit.y > .zero
            && profile.gyroscopeDegreesPerSecondPerRawUnit.z > .zero
    }

    func isFresh(_ date: Date) -> Bool {
        remainingFreshnessDuration(for: date) != nil
    }

    mutating func resetTracking() {
        filteredRollDegrees = nil
        filteredPitchDegrees = nil
        previousSampleDate = nil
    }

    mutating func locationContext(_ location: DeviceSpeedSample?) -> LocationContext {
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

    func validHeading(_ location: DeviceSpeedSample?) -> Double? {
        guard let location,
              isFreshLocation(location.observedAt),
              location.kilometersPerHour >= minimumGPSCourseSpeedKilometersPerHour,
              let course = location.courseDegrees,
              course.isFinite,
              let accuracy = location.courseAccuracyDegrees,
              accuracy.isFinite,
              accuracy <= maximumGPSCourseAccuracyDegrees
        else {
            return nil
        }
        return course.normalizedDegrees
    }

    mutating func filteredHeading(_ value: Double) -> Double {
        let normalized = value.normalizedDegrees
        guard let previous = filteredHeadingDegrees else { return normalized }
        let delta = (normalized - previous + 540).truncatingRemainder(dividingBy: 360) - 180
        return (previous + delta * Constants.headingSmoothingFactor).normalizedDegrees
    }

    func validAltitude(_ location: DeviceSpeedSample?) -> Double? {
        guard let location,
              isFreshLocation(location.observedAt),
              let altitude = location.altitudeMeters,
              altitude.isFinite,
              let accuracy = location.verticalAccuracyMeters,
              accuracy.isFinite,
              accuracy >= .zero
        else {
            return nil
        }
        return altitude
    }

    func validCoordinate(_ location: DeviceSpeedSample?) -> GeographicCoordinate? {
        guard let location, isFreshLocation(location.observedAt) else { return nil }
        return location.coordinate
    }

    func isFreshLocation(_ date: Date) -> Bool {
        let age = now().timeIntervalSince(date)
        return age >= .zero && age <= maximumLocationSampleAge
    }

    func result(
        rollDegrees: Double? = nil,
        pitchDegrees: Double? = nil,
        availability: VehicleMotionAvailability,
        observedAt: Date? = nil,
        context: LocationContext,
        calibrationToPersist: VehicleMotionCalibration? = nil
    ) -> VehicleMotionEstimation {
        .init(
            snapshot: .init(
                rollDegrees: rollDegrees,
                pitchDegrees: pitchDegrees,
                headingDegrees: context.heading,
                altitudeMeters: context.altitude,
                coordinate: context.coordinate,
                headingSource: context.headingSource,
                availability: availability,
                observedAt: observedAt
            ),
            calibrationToPersist: calibrationToPersist
        )
    }

    enum Constants {
        static let gyroscopeWeight = 0.98
        static let headingSmoothingFactor = 0.18
        static let maximumIntegrationInterval: TimeInterval = 0.25
        static let gravityCorrectionRange = 0.90 ... 1.10
        static let maximumStationarySpeed = 1.0
        static let maximumStationaryGyroDPS = 3.0
        static let minimumStableSampleCount = 20
        static let stableWindowDuration: TimeInterval = 2
        static let maximumLeanDegrees = 75.0
        static let maximumPitchDegrees = 45.0
    }
}

private extension BikeIMUVector {
    var magnitude: Double { sqrt(x * x + y * y + z * z) }
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

private extension Double {
    var radiansToDegrees: Double { self * 180 / .pi }

    var normalizedDegrees: Double {
        let value = truncatingRemainder(dividingBy: 360)
        return value >= .zero ? value : value + 360
    }
}
// swiftlint:enable file_length
