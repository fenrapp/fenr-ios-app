public struct ObserveDeviceSpeedUseCase: Sendable {
    private let repository: DeviceSpeedRepository

    public init(repository: DeviceSpeedRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<DeviceSpeedSample> {
        await repository.observeDeviceSpeed()
    }
}

public struct LocationAuthorizationStatusUseCase: Sendable {
    private let repository: DeviceSpeedRepository

    public init(repository: DeviceSpeedRepository) {
        self.repository = repository
    }

    public func execute() async -> LocationAuthorizationStatus {
        await repository.locationAuthorizationStatus()
    }
}

public struct RequestLocationAuthorizationUseCase: Sendable {
    private let repository: DeviceSpeedRepository

    public init(repository: DeviceSpeedRepository) {
        self.repository = repository
    }

    public func execute() async {
        await repository.requestLocationAuthorization()
    }
}
