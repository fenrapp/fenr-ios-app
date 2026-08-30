@preconcurrency import CoreLocation

final class TestLocationManager: CLLocationManager {
    var simulatedAuthorizationStatus: CLAuthorizationStatus
    private(set) var authorizationRequestCount = 0
    private(set) var startUpdatingLocationCount = 0
    private(set) var stopUpdatingLocationCount = 0

    init(authorizationStatus: CLAuthorizationStatus = .notDetermined) {
        simulatedAuthorizationStatus = authorizationStatus
        super.init()
    }

    override var authorizationStatus: CLAuthorizationStatus {
        simulatedAuthorizationStatus
    }

    override func requestWhenInUseAuthorization() {
        authorizationRequestCount += 1
    }

    override func startUpdatingLocation() {
        startUpdatingLocationCount += 1
    }

    override func stopUpdatingLocation() {
        stopUpdatingLocationCount += 1
    }
}
