@preconcurrency import CoreLocation
import EnvironmentDomain

@MainActor
public final class CoreLocationDeviceSpeedRepository: NSObject, DeviceSpeedRepository {
    private let locationManager = CLLocationManager()
    private var continuations: [UUID: AsyncStream<DeviceSpeedSample>.Continuation] = [:]

    override public init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .automotiveNavigation
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
    }

    public func observeDeviceSpeed() -> AsyncStream<DeviceSpeedSample> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<DeviceSpeedSample>.makeStream()
        continuations[id] = continuation
        updateLocationMonitoring()
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.removeContinuation(id) }
        }
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
            locationManager.stopUpdatingLocation()
            return
        }
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }
}

extension CoreLocationDeviceSpeedRepository: @preconcurrency CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        updateLocationMonitoring()
    }

    public func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let sample = DeviceSpeedSample(
            kilometersPerHour: location.speed * Constants.metersPerSecondToKilometersPerHour,
            accuracyMetersPerSecond: location.speedAccuracy,
            observedAt: location.timestamp
        )
        continuations.values.forEach { $0.yield(sample) }
    }

    public func locationManager(_: CLLocationManager, didFailWithError _: Error) {}

    private enum Constants {
        static let metersPerSecondToKilometersPerHour = 3.6
    }
}
