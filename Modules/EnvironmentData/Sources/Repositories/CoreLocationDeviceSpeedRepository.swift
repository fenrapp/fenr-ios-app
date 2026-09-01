@preconcurrency import CoreLocation
import EnvironmentDomain

@MainActor
public final class CoreLocationDeviceSpeedRepository: NSObject, DeviceSpeedRepository,
    @preconcurrency CLLocationManagerDelegate {
    private let locationManager: CLLocationManager
    private var continuations: [UUID: AsyncStream<DeviceSpeedSample>.Continuation] = [:]
    private var isUpdatingLocation = false

    public init(locationManager: CLLocationManager) {
        self.locationManager = locationManager
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .automotiveNavigation
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
    }

    public func observeDeviceSpeed() -> AsyncStream<DeviceSpeedSample> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<DeviceSpeedSample>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.removeContinuation(id) }
        }
        continuations[id] = continuation
        updateLocationMonitoring()
        return stream
    }

    public func locationAuthorizationStatus() -> LocationAuthorizationStatus {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .restricted
        }
    }

    public func requestLocationAuthorization() {
        guard locationManager.authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
        updateLocationMonitoring()
    }

    private func updateLocationMonitoring() {
        guard !continuations.isEmpty else {
            stopUpdatingLocationIfNeeded()
            return
        }
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdatingLocationIfNeeded()
        case .notDetermined:
            stopUpdatingLocationIfNeeded()
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            stopUpdatingLocationIfNeeded()
        @unknown default:
            stopUpdatingLocationIfNeeded()
        }
    }

    private func startUpdatingLocationIfNeeded() {
        guard !isUpdatingLocation else { return }
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }

    private func stopUpdatingLocationIfNeeded() {
        guard isUpdatingLocation else { return }
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }

    public func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        updateLocationMonitoring()
    }

    public func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let sample = DeviceSpeedSample(
            kilometersPerHour: location.speed * Constants.metersPerSecondToKilometersPerHour,
            accuracyMetersPerSecond: location.speedAccuracy,
            courseDegrees: location.course >= .zero ? location.course : nil,
            courseAccuracyDegrees: location.courseAccuracy >= .zero ? location.courseAccuracy : nil,
            altitudeMeters: location.verticalAccuracy >= .zero ? location.altitude : nil,
            verticalAccuracyMeters: location.verticalAccuracy >= .zero ? location.verticalAccuracy : nil,
            horizontalAccuracyMeters: location.horizontalAccuracy >= .zero ? location.horizontalAccuracy : nil,
            coordinate: coordinate(from: location),
            observedAt: location.timestamp
        )
        continuations.values.forEach { $0.yield(sample) }
    }

    public func locationManager(_: CLLocationManager, didFailWithError _: Error) {}

    private enum Constants {
        static let metersPerSecondToKilometersPerHour = 3.6
    }

    private func coordinate(from location: CLLocation) -> GeographicCoordinate? {
        guard location.horizontalAccuracy.isFinite,
              location.horizontalAccuracy >= .zero,
              CLLocationCoordinate2DIsValid(location.coordinate) else { return nil }
        return GeographicCoordinate(
            latitudeDegrees: location.coordinate.latitude,
            longitudeDegrees: location.coordinate.longitude
        )
    }
}
