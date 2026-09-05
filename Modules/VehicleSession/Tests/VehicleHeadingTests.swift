import EnvironmentDomain
import Foundation
import Testing
import TestSupport
@testable import VehicleSession

@Suite("Live compass")
struct VehicleHeadingTests {
    @Test("Stationary heading works without a GPS position and moving GPS course takes precedence")
    func resolvesSources() {
        let now = Date(timeIntervalSince1970: 100)
        var resolver = VehicleMotionLocationResolver(
            now: { now }, maximumSampleAge: 5,
            minimumCourseSpeedKilometersPerHour: 5, maximumCourseAccuracyDegrees: 35
        )
        let compass = DeviceHeadingSample(degrees: 90, accuracyDegrees: 5, observedAt: now)
        let stationary = resolver.resolve(nil, compass: compass)
        #expect(stationary.heading == 90)
        #expect(stationary.headingSource == .compass)
        #expect(stationary.coordinate == nil)
        let location = DeviceSpeedSample(
            kilometersPerHour: 30, accuracyMetersPerSecond: 1,
            courseDegrees: 180, courseAccuracyDegrees: 2, observedAt: now
        )
        #expect(resolver.resolve(location, compass: compass).heading == 180)
        #expect(resolver.resolve(location, compass: compass).headingSource == .gpsCourse)
        #expect(resolver.resolve(nil, compass: compass).heading == 90)
    }

    @Test("Invalid, inaccurate and stale compass data never becomes a live heading", arguments: [
        DeviceHeadingSample(degrees: 90, accuracyDegrees: -1, observedAt: Date(timeIntervalSince1970: 100)),
        DeviceHeadingSample(degrees: 90, accuracyDegrees: 60, observedAt: Date(timeIntervalSince1970: 100)),
        DeviceHeadingSample(degrees: .nan, accuracyDegrees: 1, observedAt: Date(timeIntervalSince1970: 100)),
        DeviceHeadingSample(degrees: -1, accuracyDegrees: 1, observedAt: Date(timeIntervalSince1970: 100)),
        DeviceHeadingSample(degrees: 90, accuracyDegrees: 1, observedAt: Date(timeIntervalSince1970: 90))
    ])
    func rejectsInvalidCompass(_ sample: DeviceHeadingSample) {
        var resolver = VehicleMotionLocationResolver(
            now: { Date(timeIntervalSince1970: 100) }, maximumSampleAge: 5,
            minimumCourseSpeedKilometersPerHour: 5, maximumCourseAccuracyDegrees: 35
        )
        #expect(resolver.resolve(nil, compass: sample).headingSource == .unavailable)
        #expect(resolver.resolve(nil, compass: sample).heading == nil)
    }

    @Test("Consumers share heading observation and late samples cannot survive stop or restart")
    func sharesAndStopsHeading() async {
        let fixture = makeVehicleSessionFixture()
        await fixture.service.start()
        let first = UUID()
        let second = UUID()
        await fixture.service.setLocationMonitoringRequired(true, consumerID: first)
        await fixture.service.setLocationMonitoringRequired(true, consumerID: second)
        #expect(await fixture.heading.hub.waitForSubscriber())
        #expect(await fixture.heading.subscriptions == 1)
        await fixture.heading.send(.init(degrees: 45, accuracyDegrees: 3, observedAt: fixture.now))
        #expect(await waitUntil { await fixture.latestSnapshot().motion.headingDegrees == 45 })
        await fixture.service.setLocationMonitoringRequired(false, consumerID: first)
        #expect(await fixture.latestSnapshot().motion.headingSource == .compass)
        await fixture.service.setLocationMonitoringRequired(false, consumerID: second)
        #expect(await fixture.latestSnapshot().motion.headingSource == .unavailable)
        await fixture.heading.send(.init(degrees: 200, accuracyDegrees: 3, observedAt: fixture.now))
        #expect(await fixture.latestSnapshot().motion.headingDegrees == nil)
        await fixture.service.stop()
        await fixture.service.start()
        await fixture.service.setLocationMonitoringRequired(true, consumerID: first)
        #expect(await fixture.heading.hub.waitForSubscriber())
        #expect(await waitUntil { await fixture.heading.subscriptions == 2 })
        await fixture.heading.send(.init(degrees: 120, accuracyDegrees: 3, observedAt: fixture.now))
        #expect(await waitUntil { await fixture.latestSnapshot().motion.headingDegrees == 120 })
        await fixture.service.stop()
        #expect(await fixture.latestSnapshot().motion.headingDegrees == nil)
    }

    @Test("A stopped sensor expires even without new GPS or motorcycle samples")
    func expiresHeading() async {
        let fixture = makeVehicleSessionFixture(now: Date.init, maximumSampleAge: 0.1)
        await fixture.service.start()
        await fixture.service.setLocationMonitoringRequired(true, consumerID: UUID())
        #expect(await fixture.heading.hub.waitForSubscriber())
        await fixture.heading.send(.init(degrees: 90, accuracyDegrees: 3, observedAt: .now))
        #expect(await waitUntil { await fixture.latestSnapshot().motion.headingSource == .compass })
        #expect(await waitUntil { await fixture.latestSnapshot().motion.headingSource == .unavailable })
        await fixture.service.stop()
    }
}
