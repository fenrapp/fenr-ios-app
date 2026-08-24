import EnvironmentDomain
import Foundation
import RuntimeConfiguration
import SettingsDomain

struct DeviceSpeedResolver: Sendable {
    func resolvedSpeed(
        motorcycleKilometersPerHour: Double?,
        deviceSample: DeviceSpeedSample?,
        source: SpeedSource,
        now: Date = .now
    ) -> Double? {
        let gpsSpeed = validSpeed(from: deviceSample, now: now)
        return switch source {
        case .motorcycle: motorcycleKilometersPerHour
        case .gps: gpsSpeed
        case .hybrid: gpsSpeed ?? motorcycleKilometersPerHour
        }
    }

    private func validSpeed(from sample: DeviceSpeedSample?, now: Date) -> Double? {
        guard
            let sample,
            sample.kilometersPerHour >= 0,
            sample.accuracyMetersPerSecond >= 0,
            sample.accuracyMetersPerSecond <= Constants.maximumAccuracyMetersPerSecond,
            now.timeIntervalSince(sample.observedAt) <= Constants.maximumSampleAge
        else {
            return nil
        }
        return sample.kilometersPerHour
    }

    private enum Constants {
        static let maximumAccuracyMetersPerSecond = 5.0
        static let maximumSampleAge = FENRRuntimeConstants.RideDashboard.deviceSpeedMaximumSampleAge
    }
}
