public protocol DeviceHeadingRepository: Sendable {
    func observeDeviceHeading() async -> AsyncStream<DeviceHeadingSample>
}
