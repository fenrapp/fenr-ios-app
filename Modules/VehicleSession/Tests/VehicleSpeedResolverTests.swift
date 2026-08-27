import EnvironmentDomain
import Foundation
import SettingsDomain
import Testing
@testable import VehicleSession

struct VehicleSpeedResolverTests {
    @Test("Resolves motorcycle, GPS and GPS+ speed from the same source")
    func resolvesSpeedSources() {
        let now = Date(timeIntervalSince1970: 100)
        let resolver = VehicleSpeedResolver(
            now: { now },
            maximumAccuracyMetersPerSecond: 5,
            maximumSampleAge: 3
        )
        let gps = DeviceSpeedSample(
            kilometersPerHour: 42,
            accuracyMetersPerSecond: 1,
            observedAt: now
        )

        #expect(resolver.resolvedSpeed(
            motorcycleKilometersPerHour: 35,
            deviceSample: gps,
            source: .motorcycle
        ) == 35)
        #expect(resolver.resolvedSpeed(
            motorcycleKilometersPerHour: 35,
            deviceSample: gps,
            source: .gps
        ) == 42)
        #expect(resolver.resolvedSpeed(
            motorcycleKilometersPerHour: 35,
            deviceSample: gps,
            source: .hybrid
        ) == 42)
    }

    @Test("Rejects stale, future-dated, and non-finite GPS samples")
    func rejectsInvalidSamples() {
        let now = Date(timeIntervalSince1970: 100)
        let resolver = VehicleSpeedResolver(
            now: { now },
            maximumAccuracyMetersPerSecond: 5,
            maximumSampleAge: 3
        )
        let samples = [
            DeviceSpeedSample(
                kilometersPerHour: 42,
                accuracyMetersPerSecond: 1,
                observedAt: now.addingTimeInterval(-4)
            ),
            DeviceSpeedSample(
                kilometersPerHour: 42,
                accuracyMetersPerSecond: 1,
                observedAt: now.addingTimeInterval(1)
            ),
            DeviceSpeedSample(
                kilometersPerHour: .infinity,
                accuracyMetersPerSecond: 1,
                observedAt: now
            )
        ]

        for sample in samples {
            #expect(!resolver.hasValidDeviceSpeed(sample))
            #expect(resolver.resolvedSpeed(
                motorcycleKilometersPerHour: 35,
                deviceSample: sample,
                source: .gps
            ) == nil)
        }
    }
}
