public struct ObserveDeviceHeadingUseCase: Sendable {
    private let repository: any DeviceHeadingRepository

    public init(repository: any DeviceHeadingRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<DeviceHeadingSample> {
        await repository.observeDeviceHeading()
    }
}
