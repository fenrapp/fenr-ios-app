import EnvironmentDomain
import Foundation
@testable import RideDashboard
import SettingsDomain
import Testing

@Suite("Device speed resolver")
struct DeviceSpeedResolverTests {
    private let resolver = DeviceSpeedResolver()
    private let now = Date(timeIntervalSinceReferenceDate: 100)

    @Test("Uses motorcycle telemetry in motorcycle mode")
    func usesMotorcycleSpeed() {
        let speed = resolver.resolvedSpeed(
            motorcycleKilometersPerHour: 42,
            deviceSample: validSample(speed: 60),
            source: .motorcycle,
            now: now
        )

        #expect(speed == 42)
    }

    @Test("Uses an accurate, recent GPS sample in GPS and hybrid modes")
    func usesValidDeviceSpeed() {
        let sample = validSample(speed: 60)

        #expect(resolver.resolvedSpeed(
            motorcycleKilometersPerHour: 42,
            deviceSample: sample,
            source: .gps,
            now: now
        ) == 60)
        #expect(resolver.resolvedSpeed(
            motorcycleKilometersPerHour: 42,
            deviceSample: sample,
            source: .hybrid,
            now: now
        ) == 60)
    }

    @Test("Rejects stale, imprecise, and negative GPS samples")
    func rejectsInvalidDeviceSpeed() {
        let invalidSamples = [
            DeviceSpeedSample(kilometersPerHour: 60, accuracyMetersPerSecond: 5.1, observedAt: now),
            DeviceSpeedSample(
                kilometersPerHour: 60,
                accuracyMetersPerSecond: 5,
                observedAt: now.addingTimeInterval(-3.1)
            ),
            DeviceSpeedSample(kilometersPerHour: -1, accuracyMetersPerSecond: 5, observedAt: now)
        ]

        for sample in invalidSamples {
            #expect(resolver.resolvedSpeed(
                motorcycleKilometersPerHour: 42,
                deviceSample: sample,
                source: .gps,
                now: now
            ) == nil)
            #expect(resolver.resolvedSpeed(
                motorcycleKilometersPerHour: 42,
                deviceSample: sample,
                source: .hybrid,
                now: now
            ) == 42)
        }
    }

    private func validSample(speed: Double) -> DeviceSpeedSample {
        DeviceSpeedSample(kilometersPerHour: speed, accuracyMetersPerSecond: 5, observedAt: now)
    }
}
