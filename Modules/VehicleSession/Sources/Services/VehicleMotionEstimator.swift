import BikeDomain
import EnvironmentDomain
import Foundation
public struct VehicleMotionEstimator: Sendable {
    private let profile: BikeIMUProfile?
    private let now: @Sendable () -> Date
    private let maximumSampleAge: TimeInterval
    private var attitudeFilter: VehicleAttitudeFilter
    private var calibrationTracker: VehicleMotionCalibrationTracker
    private var locationResolver: VehicleMotionLocationResolver

    public init(
        profile: BikeIMUProfile?,
        now: @escaping @Sendable () -> Date,
        maximumSampleAge: TimeInterval,
        attitudeFilter: VehicleAttitudeFilter,
        calibrationTracker: VehicleMotionCalibrationTracker,
        locationResolver: VehicleMotionLocationResolver
    ) {
        self.profile = profile
        self.now = now
        self.maximumSampleAge = maximumSampleAge
        self.attitudeFilter = attitudeFilter
        self.calibrationTracker = calibrationTracker
        self.locationResolver = locationResolver
    }

    // swiftlint:disable:next function_body_length
    public mutating func estimate(
        imuSample: BikeIMUSample?,
        calibration: VehicleMotionCalibration?,
        vin: String?,
        location: DeviceSpeedSample?,
        bikeSpeedKilometersPerHour: Double?
    ) -> VehicleMotionEstimation {
        let context = locationResolver.resolve(location)
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

        let preparation = calibrationTracker.prepare(
            sample: sample,
            calibration: calibration,
            vin: vin,
            bikeSpeedKilometersPerHour: bikeSpeedKilometersPerHour,
            profile: profile
        )
        let effectiveCalibration = preparation.calibration
        var calibrationToPersist = preparation.calibrationToPersist

        let baseAngles = attitudeFilter.update(
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

        if calibrationTracker.isZeroRequested {
            guard preparation.completedStableWindow else {
                let displayed = applyingOffsets(baseAngles, calibration: effectiveCalibration)
                return result(
                    rollDegrees: displayed.roll,
                    pitchDegrees: displayed.pitch,
                    availability: .zeroing,
                    observedAt: sample.observedAt,
                    context: context
                )
            }
            effectiveCalibration = calibrationTracker.completeZero(
                baseAngles: baseAngles,
                calibration: effectiveCalibration,
                profile: profile,
                observedAt: sample.observedAt
            )
            calibrationToPersist = effectiveCalibration
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
        calibrationTracker.requestZero()
    }

    public mutating func reset() {
        resetTracking()
        calibrationTracker.reset()
        locationResolver.reset()
    }

    func remainingFreshnessDuration(for date: Date) -> Duration? {
        let age = now().timeIntervalSince(date)
        guard age.isFinite, age >= .zero, age < maximumSampleAge else { return nil }
        return .seconds(maximumSampleAge - age)
    }
}

private extension BikeIMUVector {
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

private extension VehicleMotionEstimator {
    func applyingOffsets(
        _ angles: VehicleMotionAngles,
        calibration: VehicleMotionCalibration
    ) -> VehicleMotionAngles {
        .init(
            roll: angles.roll + calibration.rollZeroOffsetDegrees,
            pitch: angles.pitch + calibration.pitchZeroOffsetDegrees
        )
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
        attitudeFilter.reset()
    }

    func result(
        rollDegrees: Double? = nil,
        pitchDegrees: Double? = nil,
        availability: VehicleMotionAvailability,
        observedAt: Date? = nil,
        context: VehicleMotionLocationContext,
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
        static let maximumLeanDegrees = 75.0
        static let maximumPitchDegrees = 45.0
    }
}
