import BikeDomain
import EnvironmentDomain
import Foundation
import Testing
@testable import VehicleSession

// The boundary-focused scenarios intentionally share one exact numeric fixture.
// swiftlint:disable file_length

@Suite("Vehicle attitude filter")
struct VehicleAttitudeFilterTests {
    @Test("Initializes roll and pitch from trustworthy gravity")
    func gravityInitialization() {
        var filter = VehicleAttitudeFilter()

        let angles = filter.update(
            sample: sample(
                acceleration: gravityVector(rollDegrees: 12, pitchDegrees: -5),
                at: referenceDate
            ),
            calibration: nil,
            profile: profile
        )

        expect(angles?.roll, equals: 12)
        expect(angles?.pitch, equals: -5)
    }

    @Test("Gravity correction accepts exact bounds and rejects values outside them")
    func gravityCorrectionRangeBoundaries() {
        for gravityRaw in [900.0, 1_100.0] {
            var filter = VehicleAttitudeFilter()
            let angles = filter.update(
                sample: sample(
                    acceleration: .init(x: 0, y: 0, z: gravityRaw),
                    at: referenceDate
                ),
                calibration: nil,
                profile: profile
            )
            #expect(angles != nil)
        }
        for gravityRaw in [899.999, 1_100.001] {
            var filter = VehicleAttitudeFilter()
            let angles = filter.update(
                sample: sample(
                    acceleration: .init(x: 0, y: 0, z: gravityRaw),
                    at: referenceDate
                ),
                calibration: nil,
                profile: profile
            )
            #expect(angles == nil)
        }
    }

    @Test("Subtracts bias before transforming and integrating gyroscope rates")
    func gyroscopeIntegrationOrder() {
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
        let biasedCalibration = VehicleMotionCalibration(
            vin: vin,
            gyroscopeBiasXRaw: 0,
            gyroscopeBiasYRaw: 5,
            gyroscopeBiasZRaw: 0,
            profileVersion: transformedProfile.version,
            calibratedAt: referenceDate
        )
        var filter = VehicleAttitudeFilter()
        _ = filter.update(
            sample: levelSample(at: referenceDate),
            calibration: biasedCalibration,
            profile: transformedProfile
        )

        let angles = filter.update(
            sample: sample(
                acceleration: .init(x: 0, y: 0, z: 0),
                gyroscope: .init(x: 0, y: 15, z: 0),
                at: referenceDate.addingTimeInterval(0.1)
            ),
            calibration: biasedCalibration,
            profile: transformedProfile
        )

        expect(angles?.roll, equals: -0.1)
        expect(angles?.pitch, equals: 0)
    }

    @Test("Applies the complementary gravity correction after integration")
    func complementaryCorrection() {
        var filter = VehicleAttitudeFilter()
        _ = filter.update(
            sample: levelSample(at: referenceDate),
            calibration: calibration,
            profile: profile
        )

        let angles = filter.update(
            sample: sample(
                acceleration: gravityVector(rollDegrees: 10, pitchDegrees: -5),
                at: referenceDate.addingTimeInterval(0.1)
            ),
            calibration: calibration,
            profile: profile
        )

        expect(angles?.roll, equals: 0.2)
        expect(angles?.pitch, equals: -0.1)
    }

    @Test("Rejects invalid and nonfinite gravity during initialization")
    func invalidAccelerationInitialization() {
        var filter = VehicleAttitudeFilter()

        let rejected = filter.update(
            sample: sample(
                acceleration: .init(x: 0, y: 0, z: 2_000),
                at: referenceDate
            ),
            calibration: calibration,
            profile: profile
        )
        let nonfinite = filter.update(
            sample: sample(
                acceleration: .init(x: 0, y: 0, z: .infinity),
                at: referenceDate.addingTimeInterval(0.05)
            ),
            calibration: calibration,
            profile: profile
        )
        let recovered = filter.update(
            sample: levelSample(at: referenceDate.addingTimeInterval(0.1)),
            calibration: calibration,
            profile: profile
        )

        #expect(rejected == nil)
        #expect(nonfinite == nil)
        expect(recovered?.roll, equals: 0)
        expect(recovered?.pitch, equals: 0)
    }

    @Test("Nonfinite rates are rejected without advancing filter time")
    func nonfiniteGyroscopeRate() {
        var filter = VehicleAttitudeFilter()
        _ = filter.update(
            sample: levelSample(at: referenceDate),
            calibration: calibration,
            profile: profile
        )

        let rejected = filter.update(
            sample: sample(
                acceleration: .init(x: 0, y: 0, z: 0),
                gyroscope: .init(x: .infinity, y: 0, z: 0),
                at: referenceDate.addingTimeInterval(0.1)
            ),
            calibration: calibration,
            profile: profile
        )
        let recovered = filter.update(
            sample: sample(
                acceleration: .init(x: 0, y: 0, z: 0),
                gyroscope: .init(x: 100, y: 0, z: 0),
                at: referenceDate.addingTimeInterval(0.2)
            ),
            calibration: calibration,
            profile: profile
        )

        #expect(rejected == nil)
        expect(recovered?.roll, equals: 2)
    }
}

extension VehicleAttitudeFilterTests {
    @Test("Equal timestamps are rejected without resetting accumulated attitude")
    func equalTimestamp() {
        var filter = VehicleAttitudeFilter()
        _ = filter.update(
            sample: levelSample(at: referenceDate),
            calibration: calibration,
            profile: profile
        )

        let rejected = filter.update(
            sample: levelSample(
                gyroscope: .init(x: 100, y: 0, z: 0),
                at: referenceDate
            ),
            calibration: calibration,
            profile: profile
        )
        let recovered = filter.update(
            sample: sample(
                acceleration: .init(x: 0, y: 0, z: 0),
                gyroscope: .init(x: 100, y: 0, z: 0),
                at: referenceDate.addingTimeInterval(0.1)
            ),
            calibration: calibration,
            profile: profile
        )

        #expect(rejected == nil)
        expect(recovered?.roll, equals: 1)
    }

    @Test("Backward timestamps reset the filter before a gravity reinitialization")
    func backwardTimestamp() {
        var filter = VehicleAttitudeFilter()
        _ = filter.update(
            sample: levelSample(at: referenceDate),
            calibration: calibration,
            profile: profile
        )

        let rejected = filter.update(
            sample: levelSample(at: referenceDate.addingTimeInterval(-1)),
            calibration: calibration,
            profile: profile
        )
        let recovered = filter.update(
            sample: sample(
                acceleration: gravityVector(rollDegrees: 7, pitchDegrees: 3),
                at: referenceDate.addingTimeInterval(-0.9)
            ),
            calibration: calibration,
            profile: profile
        )

        #expect(rejected == nil)
        expect(recovered?.roll, equals: 7)
        expect(recovered?.pitch, equals: 3)
    }

    @Test("Exactly two hundred fifty milliseconds remains integrable")
    func exactMaximumIntegrationGap() {
        var filter = VehicleAttitudeFilter()
        _ = filter.update(
            sample: levelSample(at: referenceDate),
            calibration: calibration,
            profile: profile
        )

        let angles = filter.update(
            sample: sample(
                acceleration: .init(x: 0, y: 0, z: 0),
                gyroscope: .init(x: 100, y: -40, z: 0),
                at: referenceDate.addingTimeInterval(0.25)
            ),
            calibration: calibration,
            profile: profile
        )

        expect(angles?.roll, equals: 2.5)
        expect(angles?.pitch, equals: -1)
    }

    @Test("A gap over two hundred fifty milliseconds reanchors from gravity")
    func oversizedGapReanchors() {
        var filter = VehicleAttitudeFilter()
        _ = filter.update(
            sample: levelSample(at: referenceDate),
            calibration: calibration,
            profile: profile
        )

        let angles = filter.update(
            sample: sample(
                acceleration: gravityVector(rollDegrees: 6, pitchDegrees: -4),
                gyroscope: .init(x: 500, y: 500, z: 0),
                at: referenceDate.addingTimeInterval(0.250_001)
            ),
            calibration: calibration,
            profile: profile
        )

        expect(angles?.roll, equals: 6)
        expect(angles?.pitch, equals: -4)
    }

    @Test("An oversized gap without gravity stays reset until a valid sample")
    func oversizedGapWithoutGravity() {
        var filter = VehicleAttitudeFilter()
        _ = filter.update(
            sample: levelSample(at: referenceDate),
            calibration: calibration,
            profile: profile
        )

        let rejected = filter.update(
            sample: sample(
                acceleration: .init(x: 0, y: 0, z: 0),
                gyroscope: .init(x: 100, y: 0, z: 0),
                at: referenceDate.addingTimeInterval(0.3)
            ),
            calibration: calibration,
            profile: profile
        )
        let reanchored = filter.update(
            sample: sample(
                acceleration: gravityVector(rollDegrees: -8, pitchDegrees: 2),
                at: referenceDate.addingTimeInterval(0.4)
            ),
            calibration: calibration,
            profile: profile
        )

        #expect(rejected == nil)
        expect(reanchored?.roll, equals: -8)
        expect(reanchored?.pitch, equals: 2)
    }

    @Test("Reset discards accumulated attitude and timing")
    func reset() {
        var filter = VehicleAttitudeFilter()
        _ = filter.update(
            sample: levelSample(at: referenceDate),
            calibration: calibration,
            profile: profile
        )
        _ = filter.update(
            sample: sample(
                acceleration: .init(x: 0, y: 0, z: 0),
                gyroscope: .init(x: 100, y: 0, z: 0),
                at: referenceDate.addingTimeInterval(0.1)
            ),
            calibration: calibration,
            profile: profile
        )

        filter.reset()
        let rejected = filter.update(
            sample: sample(
                acceleration: .init(x: 0, y: 0, z: 0),
                at: referenceDate.addingTimeInterval(0.2)
            ),
            calibration: calibration,
            profile: profile
        )
        let reinitialized = filter.update(
            sample: levelSample(at: referenceDate.addingTimeInterval(0.3)),
            calibration: calibration,
            profile: profile
        )

        #expect(rejected == nil)
        expect(reinitialized?.roll, equals: 0)
        expect(reinitialized?.pitch, equals: 0)
    }
}

private extension VehicleAttitudeFilterTests {
    var referenceDate: Date { Date(timeIntervalSinceReferenceDate: 1_000) }
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

    var calibration: VehicleMotionCalibration {
        .init(
            vin: vin,
            gyroscopeBiasXRaw: 0,
            gyroscopeBiasYRaw: 0,
            gyroscopeBiasZRaw: 0,
            profileVersion: profile.version,
            calibratedAt: referenceDate
        )
    }

    func levelSample(
        gyroscope: BikeIMUVector = .init(x: 0, y: 0, z: 0),
        at date: Date
    ) -> BikeIMUSample {
        sample(
            acceleration: .init(x: 0, y: 0, z: 1_000),
            gyroscope: gyroscope,
            at: date
        )
    }

    func sample(
        acceleration: BikeIMUVector,
        gyroscope: BikeIMUVector = .init(x: 0, y: 0, z: 0),
        at date: Date
    ) -> BikeIMUSample {
        .init(
            accelerationRaw: acceleration,
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

    func expect(
        _ value: Double?,
        equals expected: Double,
        tolerance: Double = 0.000_001
    ) {
        #expect(abs((value ?? .infinity) - expected) < tolerance)
    }
}
// swiftlint:enable file_length
