public struct ObserveDeviceSpeedUseCase: Sendable {
    private let repository: DeviceSpeedRepository
    private let requestsAuthorization: Bool

    public init(repository: DeviceSpeedRepository, requestsAuthorization: Bool = false) {
        self.repository = repository
        self.requestsAuthorization = requestsAuthorization
    }

    public func execute() async -> AsyncStream<DeviceSpeedSample> {
        if requestsAuthorization { await repository.requestLocationAuthorization() }
        return await repository.observeDeviceSpeed()
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
