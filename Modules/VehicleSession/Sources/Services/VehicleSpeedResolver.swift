import EnvironmentDomain
import Foundation
import SettingsDomain

public struct VehicleSpeedResolver: Sendable {
    private let now: @Sendable () -> Date
    private let maximumAccuracyMetersPerSecond: Double
    private let maximumSampleAge: TimeInterval

    public init(
        now: @escaping @Sendable () -> Date,
        maximumAccuracyMetersPerSecond: Double,
        maximumSampleAge: TimeInterval
    ) {
        self.now = now
        self.maximumAccuracyMetersPerSecond = maximumAccuracyMetersPerSecond
        self.maximumSampleAge = maximumSampleAge
    }

    public func resolvedSpeed(
        motorcycleKilometersPerHour: Double?,
        deviceSample: DeviceSpeedSample?,
        source: SpeedSource
    ) -> Double? {
        let gpsSpeed = validSpeed(from: deviceSample)
        return switch source {
        case .motorcycle: motorcycleKilometersPerHour
        case .gps: gpsSpeed
        case .hybrid: gpsSpeed ?? motorcycleKilometersPerHour
        }
    }

    public func hasValidDeviceSpeed(_ sample: DeviceSpeedSample?) -> Bool {
        validSpeed(from: sample) != nil
    }

    func remainingValidity(of sample: DeviceSpeedSample) -> TimeInterval? {
        guard hasValidValues(sample) else { return nil }
        let age = now().timeIntervalSince(sample.observedAt)
        guard age >= .zero, age <= maximumSampleAge else { return nil }
        return maximumSampleAge - age
    }

    private func validSpeed(from sample: DeviceSpeedSample?) -> Double? {
        guard let sample, remainingValidity(of: sample) != nil else { return nil }
        return sample.kilometersPerHour
    }

    private func hasValidValues(_ sample: DeviceSpeedSample) -> Bool {
        sample.kilometersPerHour.isFinite
            && sample.kilometersPerHour >= .zero
            && sample.accuracyMetersPerSecond.isFinite
            && sample.accuracyMetersPerSecond >= .zero
            && sample.accuracyMetersPerSecond <= maximumAccuracyMetersPerSecond
    }
}
