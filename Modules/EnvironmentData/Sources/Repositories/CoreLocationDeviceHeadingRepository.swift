@preconcurrency import CoreLocation
import EnvironmentDomain

@MainActor
public final class CoreLocationDeviceHeadingRepository: NSObject, DeviceHeadingRepository,
    @preconcurrency CLLocationManagerDelegate {
    private let locationManager: CLLocationManager
    private let isHeadingAvailable: @MainActor () -> Bool
    private let headingOrientation: @MainActor () -> CLDeviceOrientation
    private var continuations: [UUID: AsyncStream<DeviceHeadingSample>.Continuation] = [:]
    private var isUpdating = false

    public init(
        locationManager: CLLocationManager,
        isHeadingAvailable: @escaping @MainActor () -> Bool,
        headingOrientation: @escaping @MainActor () -> CLDeviceOrientation
    ) {
        self.locationManager = locationManager
        self.isHeadingAvailable = isHeadingAvailable
        self.headingOrientation = headingOrientation
        super.init()
        locationManager.delegate = self
        locationManager.headingFilter = kCLHeadingFilterNone
    }

    public func observeDeviceHeading() -> AsyncStream<DeviceHeadingSample> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<DeviceHeadingSample>.makeStream(bufferingPolicy: .bufferingNewest(1))
        guard isHeadingAvailable() else {
            continuation.finish()
            return stream
        }
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.removeContinuation(id) }
        }
        continuations[id] = continuation
        if !isUpdating {
            isUpdating = true
            locationManager.headingOrientation = headingOrientation()
            locationManager.startUpdatingHeading()
        }
        return stream
    }

    public func locationManager(_: CLLocationManager, didUpdateHeading heading: CLHeading) {
        guard isUpdating else { return }
        let orientation = headingOrientation()
        guard locationManager.headingOrientation == orientation else {
            locationManager.headingOrientation = orientation
            return
        }
        let degrees = heading.trueHeading >= .zero ? heading.trueHeading : heading.magneticHeading
        let sample = DeviceHeadingSample(
            degrees: degrees, accuracyDegrees: heading.headingAccuracy, observedAt: heading.timestamp
        )
        continuations.values.forEach { $0.yield(sample) }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
        guard continuations.isEmpty, isUpdating else { return }
        isUpdating = false
        locationManager.stopUpdatingHeading()
    }
}
