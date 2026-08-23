public protocol DeviceSpeedRepository: Sendable {
    func observeDeviceSpeed() async -> AsyncStream<DeviceSpeedSample>
    func locationAuthorizationStatus() async -> LocationAuthorizationStatus
    func requestLocationAuthorization() async
}
