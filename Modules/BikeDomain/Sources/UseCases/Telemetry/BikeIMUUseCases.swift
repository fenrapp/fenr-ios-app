public struct ObserveBikeIMUUseCase: Sendable {
    private let repository: any BikeIMURepository

    public init(repository: any BikeIMURepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<BikeIMUSample> {
        await repository.observeIMU()
    }
}

public struct StartBikeIMUMonitoringUseCase: Sendable {
    private let repository: any BikeIMURepository

    public init(repository: any BikeIMURepository) {
        self.repository = repository
    }

    public func execute() async throws {
        try await repository.startIMUMonitoring()
    }
}

public struct StopBikeIMUMonitoringUseCase: Sendable {
    private let repository: any BikeIMURepository

    public init(repository: any BikeIMURepository) {
        self.repository = repository
    }

    public func execute() async {
        await repository.stopIMUMonitoring()
    }
}
