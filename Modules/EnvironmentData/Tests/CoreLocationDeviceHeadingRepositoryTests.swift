import CoreLocation
import EnvironmentData
import Testing
import TestSupport

@MainActor
@Suite("Device compass repository")
struct CoreLocationDeviceHeadingRepositoryTests {
    @Test("Magnetic compass starts once without requesting GPS authorization")
    func observesWithoutLocation() async throws {
        let manager = TestLocationManager()
        let repository = makeDeviceHeadingRepository(manager: manager)
        let first = repository.observeDeviceHeading()
        let second = repository.observeDeviceHeading()
        #expect(manager.startUpdatingHeadingCount == 1)
        #expect(manager.authorizationRequestCount == 0)
        #expect(manager.startUpdatingLocationCount == 0)
        #expect(manager.headingOrientation == .landscapeLeft)
        let heading = TestHeading()
        repository.locationManager(manager, didUpdateHeading: heading)
        var iterator = first.makeAsyncIterator()
        let sample = try #require(await iterator.next())
        #expect(sample.degrees == 90)
        #expect(sample.accuracyDegrees == 4)
        #expect(sample.observedAt == heading.timestamp)
        withExtendedLifetime(second) {}
    }

    @Test("Unsupported sensors complete without starting location services")
    func handlesUnavailableSensor() async {
        let manager = TestLocationManager()
        let repository = makeDeviceHeadingRepository(manager: manager, available: false)
        var iterator = repository.observeDeviceHeading().makeAsyncIterator()
        #expect(await iterator.next() == nil)
        #expect(manager.startUpdatingHeadingCount == 0)
        #expect(manager.authorizationRequestCount == 0)
    }

    @Test("Releasing the last observer stops the magnetometer")
    func stopsAfterLastObserver() async {
        let manager = TestLocationManager()
        let repository = makeDeviceHeadingRepository(manager: manager)
        let first = repository.observeDeviceHeading()
        let second = repository.observeDeviceHeading()
        let firstTask = Task { for await _ in first {} }
        let secondTask = Task { for await _ in second {} }
        firstTask.cancel()
        await firstTask.value
        #expect(manager.stopUpdatingHeadingCount == 0)
        secondTask.cancel()
        await secondTask.value
        #expect(await waitUntil { manager.stopUpdatingHeadingCount == 1 })
    }
}
