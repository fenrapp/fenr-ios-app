public protocol DeviceMotionRepository: Sendable {
    func observeDeviceMotion() async -> AsyncStream<DeviceMotionSample>
}
