@preconcurrency import CoreLocation
@testable import EnvironmentData
import EnvironmentDomain
import Foundation
import Testing
import TestSupport

@MainActor
@Suite("Core Location device speed repository")
struct CoreLocationDeviceSpeedRepositoryTests {
    @Test("Configures Core Location for automotive speed updates")
    func configuresLocationManager() {
        let manager = TestLocationManager()
        let repository = CoreLocationDeviceSpeedRepository(locationManager: manager)

        #expect(manager.delegate === repository)
        #expect(manager.activityType == .automotiveNavigation)
        #expect(manager.desiredAccuracy == kCLLocationAccuracyBest)
        #expect(manager.distanceFilter == kCLDistanceFilterNone)
    }

    @Test("Maps every Core Location authorization state", arguments: [
        (CLAuthorizationStatus.authorizedAlways, LocationAuthorizationStatus.authorized),
        (CLAuthorizationStatus.authorizedWhenInUse, LocationAuthorizationStatus.authorized),
        (CLAuthorizationStatus.denied, LocationAuthorizationStatus.denied),
        (CLAuthorizationStatus.restricted, LocationAuthorizationStatus.restricted),
        (CLAuthorizationStatus.notDetermined, LocationAuthorizationStatus.notDetermined)
    ])
    func mapsAuthorizationStatus(
        status: CLAuthorizationStatus,
        expected: LocationAuthorizationStatus
    ) {
        let manager = TestLocationManager(authorizationStatus: status)
        let repository = CoreLocationDeviceSpeedRepository(locationManager: manager)

        #expect(repository.locationAuthorizationStatus() == expected)
    }

    @Test("Requests authorization without starting updates when status is not determined")
    func requestsUndeterminedAuthorization() {
        let manager = TestLocationManager()
        let repository = CoreLocationDeviceSpeedRepository(locationManager: manager)

        let stream = repository.observeDeviceSpeed()

        #expect(manager.authorizationRequestCount == 1)
        #expect(manager.startUpdatingLocationCount == 0)
        #expect(manager.stopUpdatingLocationCount == 0)
        withExtendedLifetime(stream) {}
    }

    @Test("Two subscribers start location updates only once")
    func twoSubscribersStartOnce() {
        let manager = TestLocationManager(authorizationStatus: .authorizedWhenInUse)
        let repository = CoreLocationDeviceSpeedRepository(locationManager: manager)

        let firstStream = repository.observeDeviceSpeed()
        let secondStream = repository.observeDeviceSpeed()

        #expect(manager.startUpdatingLocationCount == 1)
        #expect(manager.stopUpdatingLocationCount == 0)
        withExtendedLifetime((firstStream, secondStream)) {}
    }

    @Test("Cancelling the last subscriber stops location updates")
    func cancellationStopsOnlyAfterLastSubscriber() async {
        let manager = TestLocationManager(authorizationStatus: .authorizedWhenInUse)
        let repository = CoreLocationDeviceSpeedRepository(locationManager: manager)
        let firstStream = repository.observeDeviceSpeed()
        let secondStream = repository.observeDeviceSpeed()
        let firstTask = Task {
            for await _ in firstStream {}
        }
        let secondTask = Task {
            for await _ in secondStream {}
        }

        firstTask.cancel()
        await firstTask.value
        #expect(manager.stopUpdatingLocationCount == 0)

        secondTask.cancel()
        await secondTask.value
        #expect(await waitUntil { manager.stopUpdatingLocationCount == 1 })
        #expect(manager.startUpdatingLocationCount == 1)
    }

    @Test("Losing authorization stops active location updates", arguments: [
        CLAuthorizationStatus.denied,
        CLAuthorizationStatus.restricted
    ])
    func losingAuthorizationStopsUpdates(status: CLAuthorizationStatus) {
        let manager = TestLocationManager(authorizationStatus: .authorizedWhenInUse)
        let repository = CoreLocationDeviceSpeedRepository(locationManager: manager)
        let stream = repository.observeDeviceSpeed()

        manager.simulatedAuthorizationStatus = status
        repository.locationManagerDidChangeAuthorization(manager)

        #expect(manager.startUpdatingLocationCount == 1)
        #expect(manager.stopUpdatingLocationCount == 1)
        withExtendedLifetime(stream) {}
    }

    @Test("Recovering authorization restarts location updates once")
    func recoveringAuthorizationRestartsUpdates() {
        let manager = TestLocationManager(authorizationStatus: .authorizedWhenInUse)
        let repository = CoreLocationDeviceSpeedRepository(locationManager: manager)
        let stream = repository.observeDeviceSpeed()
        manager.simulatedAuthorizationStatus = .denied
        repository.locationManagerDidChangeAuthorization(manager)

        manager.simulatedAuthorizationStatus = .authorizedAlways
        repository.locationManagerDidChangeAuthorization(manager)
        repository.locationManagerDidChangeAuthorization(manager)

        #expect(manager.startUpdatingLocationCount == 2)
        #expect(manager.stopUpdatingLocationCount == 1)
        withExtendedLifetime(stream) {}
    }

    @Test("Maps every available CLLocation speed and geometry field")
    func mapsCompleteLocation() async throws {
        let manager = TestLocationManager(authorizationStatus: .authorizedWhenInUse)
        let repository = CoreLocationDeviceSpeedRepository(locationManager: manager)
        let stream = repository.observeDeviceSpeed()
        var iterator = stream.makeAsyncIterator()
        let location = makeLocation()

        repository.locationManager(manager, didUpdateLocations: [location])

        let sample = try #require(await iterator.next())
        #expect(sample.kilometersPerHour == 36)
        #expect(sample.accuracyMetersPerSecond == 0.5)
        #expect(sample.courseDegrees == 123)
        #expect(sample.courseAccuracyDegrees == 2)
        #expect(sample.altitudeMeters == 650)
        #expect(sample.verticalAccuracyMeters == 5)
        #expect(sample.horizontalAccuracyMeters == 4)
        #expect(sample.coordinate == GeographicCoordinate(latitudeDegrees: 40, longitudeDegrees: -3))
        #expect(sample.observedAt == location.timestamp)
    }

    @Test("Maps unavailable negative CLLocation fields to nil")
    func mapsNegativeOptionalFieldsToNil() async throws {
        let manager = TestLocationManager(authorizationStatus: .authorizedWhenInUse)
        let repository = CoreLocationDeviceSpeedRepository(locationManager: manager)
        let stream = repository.observeDeviceSpeed()
        var iterator = stream.makeAsyncIterator()
        let location = makeLocation(
            horizontalAccuracy: -1,
            verticalAccuracy: -1,
            course: -1,
            courseAccuracy: -1
        )

        repository.locationManager(manager, didUpdateLocations: [location])

        let sample = try #require(await iterator.next())
        #expect(sample.courseDegrees == nil)
        #expect(sample.courseAccuracyDegrees == nil)
        #expect(sample.altitudeMeters == nil)
        #expect(sample.verticalAccuracyMeters == nil)
        #expect(sample.horizontalAccuracyMeters == nil)
        #expect(sample.coordinate == nil)
    }

    @Test("Keeps only the latest pending location callback")
    func keepsLatestPendingLocation() async throws {
        let manager = TestLocationManager(authorizationStatus: .authorizedWhenInUse)
        let repository = CoreLocationDeviceSpeedRepository(locationManager: manager)
        let stream = repository.observeDeviceSpeed()
        let first = makeLocation(speed: 5, timestamp: Date(timeIntervalSince1970: 100))
        let latest = makeLocation(speed: 10, timestamp: Date(timeIntervalSince1970: 200))

        repository.locationManager(manager, didUpdateLocations: [first])
        repository.locationManager(manager, didUpdateLocations: [latest])
        var iterator = stream.makeAsyncIterator()

        let sample = try #require(await iterator.next())
        #expect(sample.kilometersPerHour == 36)
        #expect(sample.observedAt == latest.timestamp)
    }
}

private extension CoreLocationDeviceSpeedRepositoryTests {
    func makeLocation(
        horizontalAccuracy: CLLocationAccuracy = 4,
        verticalAccuracy: CLLocationAccuracy = 5,
        course: CLLocationDirection = 123,
        courseAccuracy: CLLocationDirectionAccuracy = 2,
        speed: CLLocationSpeed = 10,
        timestamp: Date = Date(timeIntervalSince1970: 100)
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40, longitude: -3),
            altitude: 650,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            courseAccuracy: courseAccuracy,
            speed: speed,
            speedAccuracy: 0.5,
            timestamp: timestamp
        )
    }
}
