import EnvironmentDomain
import Foundation
import SettingsDomain

public struct DeviceSpeedResolver: Sendable {
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

    private func validSpeed(from sample: DeviceSpeedSample?) -> Double? {
        guard
            let sample,
            sample.kilometersPerHour >= 0,
            sample.accuracyMetersPerSecond >= 0,
            sample.accuracyMetersPerSecond <= maximumAccuracyMetersPerSecond,
            now().timeIntervalSince(sample.observedAt) <= maximumSampleAge
        else {
            return nil
        }
        return sample.kilometersPerHour
    }

}
