import EnvironmentDomain
import Foundation
import Testing
@testable import VehicleSession

@Suite("Vehicle motion estimator")
struct VehicleMotionEstimatorTests {
    private let now = Date(timeIntervalSince1970: 1_000)

    @Test("Requires calibration before publishing angles")
    func requiresCalibration() {
        var estimator = makeEstimator()
        let snapshot = estimator.estimate(
            deviceMotion: sample(attitude: identity),
            calibration: nil,
            location: nil
        )

        #expect(snapshot.availability == .uncalibrated)
        #expect(snapshot.rollDegrees == nil)
    }

    @Test("Calculates roll relative to the calibrated position")
    func relativeRoll() {
        var estimator = makeEstimator()
        let roll = 24.0
        let snapshot = estimator.estimate(
            deviceMotion: sample(attitude: quaternion(rollDegrees: roll)),
            calibration: .init(vin: "FENRTEST000000001", referenceAttitude: identity, calibratedAt: now),
            location: nil
        )

        #expect(snapshot.availability == .available)
        #expect(abs((snapshot.rollDegrees ?? .zero) - roll) < 0.001)
    }

    @Test("Prefers a reliable GPS course while moving")
    func gpsCourse() {
        var estimator = makeEstimator()
        let snapshot = estimator.estimate(
            deviceMotion: sample(attitude: identity, heading: 80),
            calibration: .init(vin: "FENRTEST000000001", referenceAttitude: identity, calibratedAt: now),
            location: .init(
                kilometersPerHour: 30,
                accuracyMetersPerSecond: 1,
                courseDegrees: 312,
                courseAccuracyDegrees: 4,
                observedAt: now
            )
        )

        #expect(snapshot.headingDegrees == 312)
        #expect(snapshot.headingSource == .gpsCourse)
    }

    @Test("Publishes only fresh valid coordinates")
    func coordinates() {
        let coordinate = GeographicCoordinate(latitudeDegrees: 40.426_389, longitudeDegrees: -3.703_889)
        var estimator = makeEstimator()

        let freshSnapshot = estimator.estimate(
            deviceMotion: sample(attitude: identity),
            calibration: nil,
            location: .init(
                kilometersPerHour: 0,
                accuracyMetersPerSecond: 1,
                coordinate: coordinate,
                observedAt: now
            )
        )
        let staleSnapshot = estimator.estimate(
            deviceMotion: sample(attitude: identity),
            calibration: nil,
            location: .init(
                kilometersPerHour: 0,
                accuracyMetersPerSecond: 1,
                coordinate: coordinate,
                observedAt: now.addingTimeInterval(-2)
            )
        )

        #expect(freshSnapshot.coordinate == coordinate)
        #expect(staleSnapshot.coordinate == nil)
        #expect(GeographicCoordinate(latitudeDegrees: 91, longitudeDegrees: 0) == nil)
        #expect(GeographicCoordinate(latitudeDegrees: 0, longitudeDegrees: -181) == nil)
    }
}

private extension VehicleMotionEstimatorTests {
    var identity: MotionQuaternion {
        .init(xComponent: .zero, yComponent: .zero, zComponent: .zero, scalarComponent: 1)
    }

    func makeEstimator() -> VehicleMotionEstimator {
        .init(
            now: { now },
            maximumSampleAge: 1,
            minimumGPSCourseSpeedKilometersPerHour: 5,
            maximumGPSCourseAccuracyDegrees: 35,
            smoothingFactor: 1
        )
    }

    func sample(attitude: MotionQuaternion, heading: Double? = nil) -> DeviceMotionSample {
        .init(
            attitude: attitude,
            magneticHeadingDegrees: heading,
            magneticAccuracy: .high,
            observedAt: now
        )
    }

    func quaternion(rollDegrees: Double) -> MotionQuaternion {
        let halfAngle = rollDegrees * .pi / 360
        return .init(
            xComponent: .zero,
            yComponent: .zero,
            zComponent: sin(halfAngle),
            scalarComponent: cos(halfAngle)
        )
    }
}
