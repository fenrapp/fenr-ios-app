import BikeDomain
import EnvironmentDomain
import Foundation

public struct VehicleMotionCalibrationTracker: Sendable {
    struct Preparation {
        let calibration: VehicleMotionCalibration?
        let calibrationToPersist: VehicleMotionCalibration?
        let completedStableWindow: Bool
    }

    private var stableSamples: [BikeIMUSample] = []
    private var stableWindowStartedAt: Date?
    private var lastProcessedSample: BikeIMUSample?
    private var didRefreshBiasThisSession = false
    private(set) var isZeroRequested = false

    public init() {}

    mutating func prepare(
        sample: BikeIMUSample,
        calibration: VehicleMotionCalibration?,
        vin: String?,
        bikeSpeedKilometersPerHour: Double?,
        profile: BikeIMUProfile
    ) -> Preparation {
        let existing = valid(calibration, for: profile, vin: vin)
        guard sample != lastProcessedSample else {
            return Preparation(
                calibration: existing,
                calibrationToPersist: nil,
                completedStableWindow: hasCompletedStableWindow(at: sample.observedAt)
            )
        }
        lastProcessedSample = sample
        updateStableWindow(
            with: sample,
            isStable: isStable(
                sample,
                bikeSpeedKilometersPerHour: bikeSpeedKilometersPerHour,
                calibration: existing,
                profile: profile
            )
        )
        let completed = hasCompletedStableWindow(at: sample.observedAt)
        guard completed,
              let vin,
              existing == nil || !didRefreshBiasThisSession || isZeroRequested
        else {
            return Preparation(
                calibration: existing,
                calibrationToPersist: nil,
                completedStableWindow: completed
            )
        }
        let bias = medianGyroscopeBias()
        let refreshed = VehicleMotionCalibration(
            vin: vin,
            gyroscopeBiasXRaw: bias.x,
            gyroscopeBiasYRaw: bias.y,
            gyroscopeBiasZRaw: bias.z,
            rollZeroOffsetDegrees: existing?.rollZeroOffsetDegrees ?? .zero,
            pitchZeroOffsetDegrees: existing?.pitchZeroOffsetDegrees ?? .zero,
            profileVersion: profile.version,
            calibratedAt: sample.observedAt
        )
        didRefreshBiasThisSession = true
        clearStableWindow()
        return Preparation(
            calibration: refreshed,
            calibrationToPersist: refreshed,
            completedStableWindow: true
        )
    }

    mutating func completeZero(
        baseAngles: VehicleMotionAngles,
        calibration: VehicleMotionCalibration,
        profile: BikeIMUProfile,
        observedAt: Date
    ) -> VehicleMotionCalibration {
        isZeroRequested = false
        return VehicleMotionCalibration(
            vin: calibration.vin,
            gyroscopeBiasXRaw: calibration.gyroscopeBiasXRaw,
            gyroscopeBiasYRaw: calibration.gyroscopeBiasYRaw,
            gyroscopeBiasZRaw: calibration.gyroscopeBiasZRaw,
            rollZeroOffsetDegrees: -baseAngles.roll,
            pitchZeroOffsetDegrees: -baseAngles.pitch,
            profileVersion: profile.version,
            calibratedAt: observedAt
        )
    }

    public mutating func requestZero() {
        isZeroRequested = true
        clearStableWindow()
    }

    public mutating func reset() {
        clearStableWindow()
        lastProcessedSample = nil
        didRefreshBiasThisSession = false
        isZeroRequested = false
    }

    private func valid(
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
        else { return nil }
        return calibration
    }

    private func isStable(
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

    private mutating func updateStableWindow(with sample: BikeIMUSample, isStable: Bool) {
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

    private func hasCompletedStableWindow(at date: Date) -> Bool {
        guard stableSamples.count >= Constants.minimumStableSampleCount,
              let start = stableWindowStartedAt else { return false }
        return date.timeIntervalSince(start) >= Constants.stableWindowDuration
    }

    private mutating func clearStableWindow() {
        stableSamples.removeAll(keepingCapacity: true)
        stableWindowStartedAt = nil
    }

    private func medianGyroscopeBias() -> BikeIMUVector {
        .init(
            x: median(stableSamples.map(\.gyroscopeRaw.x)),
            y: median(stableSamples.map(\.gyroscopeRaw.y)),
            z: median(stableSamples.map(\.gyroscopeRaw.z))
        )
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return .zero }
        let middle = sorted.count / 2
        guard sorted.count.isMultiple(of: 2) else { return sorted[middle] }
        return (sorted[middle - 1] + sorted[middle]) / 2
    }

    private enum Constants {
        static let maximumIntegrationInterval: TimeInterval = 0.25
        static let gravityCorrectionRange = 0.90 ... 1.10
        static let maximumStationarySpeed = 1.0
        static let maximumStationaryGyroDPS = 3.0
        static let minimumStableSampleCount = 20
        static let stableWindowDuration: TimeInterval = 2
    }
}

private extension BikeIMUVector {
    var magnitude: Double { sqrt(x * x + y * y + z * z) }
}
