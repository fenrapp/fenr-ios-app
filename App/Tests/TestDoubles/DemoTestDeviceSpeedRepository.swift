import EnvironmentDomain

struct DemoTestDeviceSpeedRepository: DeviceSpeedRepository {
    func observeDeviceSpeed() async -> AsyncStream<DeviceSpeedSample> {
        AsyncStream { $0.finish() }
    }

    func locationAuthorizationStatus() async -> LocationAuthorizationStatus { .notDetermined }

    func requestLocationAuthorization() async {}
}
