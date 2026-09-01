import BikeDomain
import EnvironmentDomain
import Foundation

struct VehicleMotionAngles: Equatable, Sendable {
    let roll: Double
    let pitch: Double
}

struct VehicleAttitudeFilter: Sendable {
    private var filteredRollDegrees: Double?
    private var filteredPitchDegrees: Double?
    private var previousSampleDate: Date?

    mutating func update(
        sample: BikeIMUSample,
        calibration: VehicleMotionCalibration?,
        profile: BikeIMUProfile
    ) -> VehicleMotionAngles? {
        let accelerationAngles = gravityAngles(sample: sample, profile: profile)
        guard let calibration else {
            guard let accelerationAngles else {
                reset()
                return nil
            }
            return initialize(with: accelerationAngles, observedAt: sample.observedAt)
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
        guard rates.x.isFinite, rates.y.isFinite, rates.z.isFinite else { return nil }
        guard let previousSampleDate,
              let previousRoll = filteredRollDegrees,
              let previousPitch = filteredPitchDegrees
        else {
            guard let accelerationAngles else { return nil }
            return initialize(with: accelerationAngles, observedAt: sample.observedAt)
        }

        let interval = sample.observedAt.timeIntervalSince(previousSampleDate)
        guard interval > .zero else {
            if interval < .zero {
                reset()
            }
            return nil
        }
        guard interval <= Constants.maximumIntegrationInterval else {
            reset()
            guard let accelerationAngles else { return nil }
            return initialize(with: accelerationAngles, observedAt: sample.observedAt)
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

    mutating func reset() {
        filteredRollDegrees = nil
        filteredPitchDegrees = nil
        previousSampleDate = nil
    }
}

private extension VehicleAttitudeFilter {
    mutating func initialize(
        with angles: VehicleMotionAngles,
        observedAt: Date
    ) -> VehicleMotionAngles {
        filteredRollDegrees = angles.roll
        filteredPitchDegrees = angles.pitch
        previousSampleDate = observedAt
        return angles
    }

    func gravityAngles(
        sample: BikeIMUSample,
        profile: BikeIMUProfile
    ) -> VehicleMotionAngles? {
        let acceleration = profile.accelerationTransform.apply(to: sample.accelerationRaw)
        let magnitude = sqrt(
            acceleration.x * acceleration.x
                + acceleration.y * acceleration.y
                + acceleration.z * acceleration.z
        )
        guard acceleration.x.isFinite,
              acceleration.y.isFinite,
              acceleration.z.isFinite,
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

    enum Constants {
        static let gyroscopeWeight = 0.98
        static let maximumIntegrationInterval: TimeInterval = 0.25
        static let gravityCorrectionRange = 0.90 ... 1.10
    }
}

private extension Double {
    var radiansToDegrees: Double { self * 180 / .pi }
}
