import BikeDomain
import EnvironmentDomain
import Foundation
import Testing
@testable import VehicleSession

// A single synthetic profile fixture keeps all filter edge cases directly comparable.
// swiftlint:disable file_length type_body_length

@Suite("Vehicle motion estimator")
struct VehicleMotionEstimatorTests {
    private let now = Date(timeIntervalSince1970: 1_000)

    @Test("Keeps bike attitude unavailable without a physically validated profile")
    func requiresProfile() {
        var estimator = makeEstimator(profile: nil)

        let result = estimator.estimate(
            imuSample: levelSample(at: now),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 0
        )

        #expect(result.snapshot.availability == .unavailable)
        #expect(result.snapshot.rollDegrees == nil)
    }

    @Test("Requires a stable bias window before publishing angles")
    func requiresCalibration() {
        var estimator = makeEstimator()

        let result = estimator.estimate(
            imuSample: levelSample(at: now),
            calibration: nil,
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 0
        )

        #expect(result.snapshot.availability == .calibrating)
        #expect(result.snapshot.rollDegrees == nil)
    }

    @Test("Auto-calibrates gyro bias from twenty stable samples over two seconds")
    func autoCalibration() {
        var estimator = makeEstimator(maximumSampleAge: 5)
        var latest: VehicleMotionEstimation?
        for index in 0 ... 20 {
            latest = estimator.estimate(
                imuSample: levelSample(
                    gyroscope: .init(x: 4, y: -2, z: 1),
                    at: now.addingTimeInterval(Double(index) / 10 - 2)
                ),
                calibration: latest?.calibrationToPersist,
                vin: vin,
                location: nil,
                bikeSpeedKilometersPerHour: 0
            )
        }

        #expect(latest?.snapshot.availability == .available)
        #expect(latest?.calibrationToPersist?.gyroscopeBiasXRaw == 4)
        #expect(latest?.calibrationToPersist?.gyroscopeBiasYRaw == -2)
        #expect(latest?.calibrationToPersist?.gyroscopeBiasZRaw == 1)
    }

    @Test("Maps normalized motorcycle acceleration to lean and pitch")
    func staticAngles() {
        var estimator = makeEstimator()
        let roll = 20.0
        let pitch = 10.0
        let acceleration = gravityVector(rollDegrees: roll, pitchDegrees: pitch)

        let result = estimator.estimate(
            imuSample: .init(
                accelerationRaw: acceleration,
                gyroscopeRaw: .init(x: 0, y: 0, z: 0),
                observedAt: now
            ),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 0
        )

        #expect(result.snapshot.availability == .available)
        #expect(abs((result.snapshot.rollDegrees ?? .infinity) - roll) < 0.01)
        #expect(abs((result.snapshot.pitchDegrees ?? .infinity) - pitch) < 0.01)
    }

    @Test("Preserves left right and uphill downhill signs")
    func attitudeDirections() {
        for (roll, pitch) in [(-20.0, -10.0), (-20, 10), (20, -10), (20, 10)] {
            var estimator = makeEstimator()
            let result = estimator.estimate(
                imuSample: .init(
                    accelerationRaw: gravityVector(rollDegrees: roll, pitchDegrees: pitch),
                    gyroscopeRaw: .init(x: 0, y: 0, z: 0),
                    observedAt: now
                ),
                calibration: calibration(),
                vin: vin,
                location: nil,
                bikeSpeedKilometersPerHour: 0
            )

            #expect(abs((result.snapshot.rollDegrees ?? .infinity) - roll) < 0.01)
            #expect(abs((result.snapshot.pitchDegrees ?? .infinity) - pitch) < 0.01)
        }
    }

    @Test("Applies the configured sensor to bike axis transform")
    func axisTransform() {
        let transform = BikeIMUAxisTransform(
            bikeX: .negativeY,
            bikeY: .positiveX,
            bikeZ: .negativeZ
        )

        #expect(transform.apply(to: .init(x: 1, y: 2, z: 3)) == .init(x: -2, y: 1, z: -3))
    }

    @Test("Uses gyroscope integration while acceleration is outside the gravity window")
    func gyroscopeIntegration() {
        var estimator = makeEstimator()
        _ = estimator.estimate(
            imuSample: levelSample(at: now.addingTimeInterval(-0.1)),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )

        let result = estimator.estimate(
            imuSample: .init(
                accelerationRaw: .init(x: 0, y: 0, z: 2_000),
                gyroscopeRaw: .init(x: 100, y: 0, z: 0),
                observedAt: now
            ),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )

        #expect(abs((result.snapshot.rollDegrees ?? .infinity) - 1) < 0.01)
    }

    @Test("Applies the gyroscope axis transform before integration")
    func gyroscopeAxisTransform() {
        let transformedProfile = BikeIMUProfile(
            version: 1,
            accelerationTransform: profile.accelerationTransform,
            gyroscopeTransform: .init(
                bikeX: .negativeY,
                bikeY: .positiveX,
                bikeZ: .positiveZ
            ),
            gyroscopeDegreesPerSecondPerRawUnit: .init(x: 0.1, y: 0.1, z: 0.1),
            oneGRaw: 1_000
        )
        var estimator = makeEstimator(profile: transformedProfile)
        _ = estimator.estimate(
            imuSample: levelSample(at: now.addingTimeInterval(-0.1)),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )

        let result = estimator.estimate(
            imuSample: .init(
                accelerationRaw: .init(x: 0, y: 0, z: 2_000),
                gyroscopeRaw: .init(x: 0, y: 100, z: 0),
                observedAt: now
            ),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )

        #expect(abs((result.snapshot.rollDegrees ?? .infinity) + 1) < 0.01)
    }

    @Test("A persisted gyro bias prevents stationary drift for five minutes")
    func stationaryDrift() {
        let bias = BikeIMUVector(x: 5, y: -3, z: 2)
        let calibrated = VehicleMotionCalibration(
            vin: vin,
            gyroscopeBiasXRaw: bias.x,
            gyroscopeBiasYRaw: bias.y,
            gyroscopeBiasZRaw: bias.z,
            profileVersion: profile.version,
            calibratedAt: now
        )
        var estimator = makeEstimator(maximumSampleAge: 301)
        var latest: VehicleMotionEstimation?

        for index in 0 ... 3_000 {
            latest = estimator.estimate(
                imuSample: levelSample(
                    gyroscope: bias,
                    at: now.addingTimeInterval(Double(index) / 10 - 300)
                ),
                calibration: calibrated,
                vin: vin,
                location: nil,
                bikeSpeedKilometersPerHour: 0
            )
        }

        #expect(latest?.snapshot.availability == .available)
        #expect(abs(latest?.snapshot.rollDegrees ?? .infinity) < 0.01)
        #expect(abs(latest?.snapshot.pitchDegrees ?? .infinity) < 0.01)
    }

    @Test("Does not initialize attitude from anomalous acceleration")
    func anomalousAccelerationInitialization() {
        var estimator = makeEstimator()

        let anomalous = estimator.estimate(
            imuSample: .init(
                accelerationRaw: .init(x: 0, y: 1_000, z: 1_000),
                gyroscopeRaw: .init(x: 100, y: 0, z: 0),
                observedAt: now.addingTimeInterval(-0.1)
            ),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )
        let recovered = estimator.estimate(
            imuSample: levelSample(at: now),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )

        #expect(anomalous.snapshot.availability == .unavailable)
        #expect(recovered.snapshot.availability == .available)
        #expect(abs(recovered.snapshot.rollDegrees ?? .infinity) < 0.01)
    }

    @Test("Continues gyroscope integration when acceleration cannot provide gravity")
    func zeroAccelerationIntegration() {
        var estimator = makeEstimator()
        _ = estimator.estimate(
            imuSample: levelSample(at: now.addingTimeInterval(-0.1)),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )

        let result = estimator.estimate(
            imuSample: .init(
                accelerationRaw: .init(x: 0, y: 0, z: 0),
                gyroscopeRaw: .init(x: 100, y: 0, z: 0),
                observedAt: now
            ),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )

        #expect(abs((result.snapshot.rollDegrees ?? .infinity) - 1) < 0.01)
    }

    @Test("Rejects integration gaps over two hundred fifty milliseconds")
    func integrationGap() {
        var estimator = makeEstimator()
        _ = estimator.estimate(
            imuSample: levelSample(at: now.addingTimeInterval(-0.3)),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )

        let result = estimator.estimate(
            imuSample: .init(
                accelerationRaw: gravityVector(rollDegrees: 5, pitchDegrees: -4),
                gyroscopeRaw: .init(x: 300, y: 300, z: 0),
                observedAt: now
            ),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )

        #expect(abs((result.snapshot.rollDegrees ?? .infinity) - 5) < 0.01)
        #expect(abs((result.snapshot.pitchDegrees ?? .infinity) + 4) < 0.01)
    }

    @Test("Does not re-anchor after a gap unless gravity is trustworthy")
    func anomalousAccelerationAfterGap() {
        var estimator = makeEstimator()
        _ = estimator.estimate(
            imuSample: levelSample(at: now.addingTimeInterval(-0.3)),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )

        let result = estimator.estimate(
            imuSample: .init(
                accelerationRaw: .init(x: 0, y: 0, z: 2_000),
                gyroscopeRaw: .init(x: 300, y: 0, z: 0),
                observedAt: now
            ),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )

        #expect(result.snapshot.availability == .unavailable)
        #expect(result.snapshot.rollDegrees == nil)
    }

    @Test("Rejects non-increasing IMU timestamps")
    func nonIncreasingTimestamp() {
        var estimator = makeEstimator()
        _ = estimator.estimate(
            imuSample: levelSample(at: now),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )

        let result = estimator.estimate(
            imuSample: levelSample(
                gyroscope: .init(x: 100, y: 0, z: 0),
                at: now
            ),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )

        #expect(result.snapshot.availability == .unavailable)
        #expect(result.snapshot.rollDegrees == nil)
    }

    @Test("Recovers after the observation clock moves backwards")
    func timestampRollbackRecovery() {
        var estimator = makeEstimator(maximumSampleAge: 20)
        _ = estimator.estimate(
            imuSample: levelSample(at: now),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )
        let rolledBackDate = now.addingTimeInterval(-10)

        let rejected = estimator.estimate(
            imuSample: levelSample(at: rolledBackDate),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )
        let recovered = estimator.estimate(
            imuSample: levelSample(at: rolledBackDate.addingTimeInterval(0.1)),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 20
        )

        #expect(rejected.snapshot.availability == .unavailable)
        #expect(recovered.snapshot.availability == .available)
        #expect(abs(recovered.snapshot.rollDegrees ?? .infinity) < 0.01)
    }

    @Test("Rejects out of range attitude packets")
    func angleBounds() {
        var estimator = makeEstimator()
        let result = estimator.estimate(
            imuSample: .init(
                accelerationRaw: gravityVector(rollDegrees: 80, pitchDegrees: 0),
                gyroscopeRaw: .init(x: 0, y: 0, z: 0),
                observedAt: now
            ),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 0
        )

        #expect(result.snapshot.availability == .unavailable)
        #expect(result.snapshot.rollDegrees == nil)
    }

    @Test("Does not use a calibration from another VIN")
    func calibrationIsScopedByVIN() {
        var estimator = makeEstimator()
        let result = estimator.estimate(
            imuSample: levelSample(at: now),
            calibration: .init(
                vin: "OTHERBIKE00000001",
                gyroscopeBiasXRaw: 0,
                gyroscopeBiasYRaw: 0,
                gyroscopeBiasZRaw: 0,
                profileVersion: profile.version,
                calibratedAt: now
            ),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 0
        )

        #expect(result.snapshot.availability == .calibrating)
    }

    @Test("Invalidates calibration when the physical profile version changes")
    func calibrationProfileVersion() {
        var estimator = makeEstimator()
        let result = estimator.estimate(
            imuSample: levelSample(at: now),
            calibration: .init(
                vin: vin,
                gyroscopeBiasXRaw: 0,
                gyroscopeBiasYRaw: 0,
                gyroscopeBiasZRaw: 0,
                profileVersion: profile.version + 1,
                calibratedAt: now
            ),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 0
        )

        #expect(result.snapshot.availability == .calibrating)
    }

    @Test("Rejects malformed physical profiles")
    func malformedProfile() {
        let invalidProfile = BikeIMUProfile(
            version: 1,
            accelerationTransform: .init(
                bikeX: .positiveX,
                bikeY: .negativeX,
                bikeZ: .positiveZ
            ),
            gyroscopeTransform: profile.gyroscopeTransform,
            gyroscopeDegreesPerSecondPerRawUnit: .init(x: 0.1, y: 0, z: 0.1),
            oneGRaw: 1_000
        )
        var estimator = makeEstimator(profile: invalidProfile)

        let result = estimator.estimate(
            imuSample: levelSample(at: now),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 0
        )

        #expect(result.snapshot.availability == .unavailable)
    }

    @Test("Rejects auto calibration while the bike is moving")
    func movingCalibration() {
        var estimator = makeEstimator(maximumSampleAge: 5)
        var latest: VehicleMotionEstimation?
        for index in 0 ... 20 {
            latest = estimator.estimate(
                imuSample: levelSample(at: now.addingTimeInterval(Double(index) / 10 - 2)),
                calibration: nil,
                vin: vin,
                location: nil,
                bikeSpeedKilometersPerHour: 2
            )
        }

        #expect(latest?.snapshot.availability == .calibrating)
        #expect(latest?.calibrationToPersist == nil)
    }

    @Test("Requires the stable calibration samples to be continuous")
    func continuousCalibrationWindow() {
        var estimator = makeEstimator(maximumSampleAge: 5)
        var latest: VehicleMotionEstimation?
        for index in 0 ..< 20 {
            latest = estimator.estimate(
                imuSample: levelSample(
                    at: now.addingTimeInterval(Double(index) / 10 - 3)
                ),
                calibration: nil,
                vin: vin,
                location: nil,
                bikeSpeedKilometersPerHour: 0
            )
        }
        latest = estimator.estimate(
            imuSample: levelSample(at: now),
            calibration: nil,
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 0
        )

        #expect(latest?.snapshot.availability == .calibrating)
        #expect(latest?.calibrationToPersist == nil)
    }

    @Test("Zero waits for a stable window and persists offsets")
    func zero() {
        var estimator = makeEstimator(maximumSampleAge: 5)
        estimator.requestZero()
        var activeCalibration = calibration()
        var latest: VehicleMotionEstimation?
        for index in 0 ... 20 {
            latest = estimator.estimate(
                imuSample: .init(
                    accelerationRaw: gravityVector(rollDegrees: 12, pitchDegrees: -5),
                    gyroscopeRaw: .init(x: 0, y: 0, z: 0),
                    observedAt: now.addingTimeInterval(Double(index) / 10 - 2)
                ),
                calibration: activeCalibration,
                vin: vin,
                location: nil,
                bikeSpeedKilometersPerHour: 0
            )
            if let saved = latest?.calibrationToPersist {
                activeCalibration = saved
            }
        }

        #expect(latest?.snapshot.availability == .available)
        #expect(abs(latest?.snapshot.rollDegrees ?? .infinity) < 0.01)
        #expect(abs(latest?.snapshot.pitchDegrees ?? .infinity) < 0.01)
    }

    @Test("Zero remains pending while the motorcycle moves")
    func movingZero() {
        var estimator = makeEstimator(maximumSampleAge: 5)
        estimator.requestZero()
        var latest: VehicleMotionEstimation?
        for index in 0 ... 20 {
            latest = estimator.estimate(
                imuSample: levelSample(at: now.addingTimeInterval(Double(index) / 10 - 2)),
                calibration: calibration(),
                vin: vin,
                location: nil,
                bikeSpeedKilometersPerHour: 2
            )
        }

        #expect(latest?.snapshot.availability == .zeroing)
        #expect(latest?.calibrationToPersist == nil)
    }

    @Test("Publishes GPS context independently of the bike IMU")
    func gpsContext() {
        let coordinate = GeographicCoordinate(latitudeDegrees: 40.426_389, longitudeDegrees: -3.703_889)
        var estimator = makeEstimator(profile: nil)

        let result = estimator.estimate(
            imuSample: nil,
            calibration: nil,
            vin: nil,
            location: .init(
                kilometersPerHour: 30,
                accuracyMetersPerSecond: 1,
                courseDegrees: 312,
                courseAccuracyDegrees: 4,
                altitudeMeters: 742,
                verticalAccuracyMeters: 8,
                coordinate: coordinate,
                observedAt: now
            ),
            bikeSpeedKilometersPerHour: 30
        )

        #expect(result.snapshot.headingDegrees == 312)
        #expect(result.snapshot.headingSource == .gpsCourse)
        #expect(result.snapshot.altitudeMeters == 742)
        #expect(result.snapshot.coordinate == coordinate)
    }

    @Test("Marks a bike IMU sample stale after the configured age")
    func staleSample() {
        var estimator = makeEstimator()

        let result = estimator.estimate(
            imuSample: levelSample(at: now.addingTimeInterval(-2)),
            calibration: calibration(),
            vin: vin,
            location: nil,
            bikeSpeedKilometersPerHour: 0
        )

        #expect(result.snapshot.availability == .stale)
    }

    @Test("Current samples retain the full freshness lifetime")
    func remainingFreshnessDurationUsesFullLifetimeForCurrentSample() {
        let estimator = makeEstimator()

        #expect(estimator.remainingFreshnessDuration(for: now) == .milliseconds(750))
    }

    @Test("Elapsed sample age is subtracted from freshness")
    func remainingFreshnessDurationSubtractsElapsedAge() {
        let estimator = makeEstimator()

        #expect(
            estimator.remainingFreshnessDuration(for: now.addingTimeInterval(-0.5))
                == .milliseconds(250)
        )
    }

    @Test("Future samples have no remaining freshness")
    func remainingFreshnessDurationRejectsFutureSample() {
        let estimator = makeEstimator()

        #expect(estimator.remainingFreshnessDuration(for: now.addingTimeInterval(0.1)) == nil)
    }

    @Test("Samples at the freshness boundary are expired")
    func remainingFreshnessDurationRejectsExactBoundary() {
        let estimator = makeEstimator()

        #expect(estimator.remainingFreshnessDuration(for: now.addingTimeInterval(-0.75)) == nil)
    }

    @Test("Samples beyond the freshness boundary are expired")
    func remainingFreshnessDurationRejectsExpiredSample() {
        let estimator = makeEstimator()

        #expect(estimator.remainingFreshnessDuration(for: now.addingTimeInterval(-0.8)) == nil)
    }
}

private extension VehicleMotionEstimatorTests {
    var vin: String { "FENRTEST000000001" }

    var profile: BikeIMUProfile {
        .init(
            version: 1,
            accelerationTransform: .init(
                bikeX: .positiveX,
                bikeY: .positiveY,
                bikeZ: .positiveZ
            ),
            gyroscopeTransform: .init(
                bikeX: .positiveX,
                bikeY: .positiveY,
                bikeZ: .positiveZ
            ),
            gyroscopeDegreesPerSecondPerRawUnit: .init(x: 0.1, y: 0.1, z: 0.1),
            oneGRaw: 1_000
        )
    }

    func makeEstimator() -> VehicleMotionEstimator {
        makeEstimator(profile: profile)
    }

    func makeEstimator(maximumSampleAge: TimeInterval) -> VehicleMotionEstimator {
        makeEstimator(profile: profile, maximumSampleAge: maximumSampleAge)
    }

    func makeEstimator(
        profile: BikeIMUProfile?,
        maximumSampleAge: TimeInterval = 0.75
    ) -> VehicleMotionEstimator {
        VehicleMotionEstimator(
            profile: profile,
            now: { now },
            maximumSampleAge: maximumSampleAge,
            minimumGPSCourseSpeedKilometersPerHour: 5,
            maximumGPSCourseAccuracyDegrees: 35,
            maximumLocationSampleAge: 3
        )
    }

    func calibration() -> VehicleMotionCalibration {
        .init(
            vin: vin,
            gyroscopeBiasXRaw: 0,
            gyroscopeBiasYRaw: 0,
            gyroscopeBiasZRaw: 0,
            profileVersion: profile.version,
            calibratedAt: now
        )
    }

    func levelSample(
        gyroscope: BikeIMUVector = .init(x: 0, y: 0, z: 0),
        at date: Date
    ) -> BikeIMUSample {
        .init(
            accelerationRaw: .init(x: 0, y: 0, z: 1_000),
            gyroscopeRaw: gyroscope,
            observedAt: date
        )
    }

    func gravityVector(rollDegrees: Double, pitchDegrees: Double) -> BikeIMUVector {
        let roll = rollDegrees * .pi / 180
        let pitch = pitchDegrees * .pi / 180
        return .init(
            x: -sin(pitch) * 1_000,
            y: sin(roll) * cos(pitch) * 1_000,
            z: cos(roll) * cos(pitch) * 1_000
        )
    }
}
// swiftlint:enable file_length type_body_length
