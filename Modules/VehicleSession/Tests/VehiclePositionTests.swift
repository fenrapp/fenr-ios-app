import EnvironmentDomain
import Foundation
import Testing
import TestSupport
@testable import VehicleSession

@Suite("Compass position continuity")
struct VehiclePositionTests {
    @Test("Position remains usable between GPS updates while course expires sooner")
    func independentFreshness() {
        let now = Date(timeIntervalSince1970: 100)
        var resolver = VehicleMotionLocationResolver(
            now: { now }, maximumSampleAge: 3,
            minimumCourseSpeedKilometersPerHour: 5, maximumCourseAccuracyDegrees: 35,
            maximumPositionSampleAge: 30
        )
        let sample = position(at: now.addingTimeInterval(-10))
        let context = resolver.resolve(sample)
        #expect(context.headingSource == .unavailable)
        #expect(context.coordinate == sample.coordinate)
        #expect(context.altitude == 650)
        let expired = resolver.resolve(position(at: now.addingTimeInterval(-31)))
        #expect(expired.coordinate == nil)
        #expect(expired.altitude == nil)
    }

    @Test("Speed expiry and invalid intermediate GPS readings do not erase the last position")
    func retainsPositionUntilItsOwnExpiry() async {
        let fixture = makeVehicleSessionFixture(
            speedSource: .gps, now: Date.init,
            maximumSampleAge: 0.1, maximumPositionSampleAge: 1
        )
        await fixture.service.start()
        #expect(await waitUntil { await fixture.deviceSpeed.subscriptionCount() == 1 })
        let sample = position(at: .now)
        await fixture.deviceSpeed.send(sample)
        #expect(await waitUntil { await fixture.latestSnapshot().motion.coordinate == sample.coordinate })
        #expect(await waitUntil { await fixture.latestSnapshot().resolvedSpeedKilometersPerHour == nil })
        #expect(await fixture.latestSnapshot().motion.coordinate == sample.coordinate)
        #expect(await fixture.latestSnapshot().motion.altitudeMeters == 650)
        await fixture.deviceSpeed.send(.init(
            kilometersPerHour: -1, accuracyMetersPerSecond: -1, observedAt: .now
        ))
        #expect(await waitUntil { await fixture.service.deviceSpeedSample?.kilometersPerHour == -1 })
        #expect(await fixture.latestSnapshot().motion.coordinate == sample.coordinate)
        #expect(await waitUntil { await fixture.latestSnapshot().motion.coordinate == nil })
        #expect(await fixture.latestSnapshot().motion.altitudeMeters == nil)
        await fixture.service.stop()
    }

    @Test("A stationary fix works without valid speed and is cleared when observation stops")
    func invalidSpeedAndTeardown() async {
        let fixture = makeVehicleSessionFixture(maximumPositionSampleAge: 30)
        let consumer = UUID()
        await fixture.service.start()
        await fixture.service.setLocationMonitoringRequired(true, consumerID: consumer)
        #expect(await waitUntil { await fixture.deviceSpeed.subscriptionCount() == 1 })
        let sample = position(at: fixture.now, speed: -1)
        await fixture.deviceSpeed.send(sample)
        #expect(await waitUntil { await fixture.latestSnapshot().motion.coordinate == sample.coordinate })
        #expect(await fixture.latestSnapshot().isGPSAvailable == false)
        await fixture.service.setLocationMonitoringRequired(false, consumerID: consumer)
        #expect(await fixture.latestSnapshot().motion.coordinate == nil)
        #expect(await fixture.latestSnapshot().motion.altitudeMeters == nil)
        await fixture.deviceSpeed.send(sample)
        await fixture.service.stop()
        await fixture.service.start()
        await fixture.service.setLocationMonitoringRequired(true, consumerID: consumer)
        #expect(await waitUntil { await fixture.deviceSpeed.subscriptionCount() == 2 })
        #expect(await fixture.latestSnapshot().motion.coordinate == nil)
        await fixture.deviceSpeed.send(sample)
        #expect(await waitUntil { await fixture.latestSnapshot().motion.coordinate == sample.coordinate })
        await fixture.service.stop()
        #expect(await fixture.latestSnapshot().motion.coordinate == nil)
    }

    private func position(at date: Date, speed: Double = 20) -> DeviceSpeedSample {
        .init(
            kilometersPerHour: speed, accuracyMetersPerSecond: 1,
            courseDegrees: 90, courseAccuracyDegrees: 2,
            altitudeMeters: 650, verticalAccuracyMeters: 2,
            coordinate: .init(latitudeDegrees: 40.4, longitudeDegrees: -3.7),
            observedAt: date
        )
    }
}
