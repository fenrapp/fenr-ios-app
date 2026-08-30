import BikeDomain

actor SpyBikeRepository: BikeRepository {
    private var currentConnectedVIN: String?
    private var disconnected = false
    private var retriedSecurityHandshake = false
    private var readTelemetrySnapshot = false
    private var readBikeStatusSnapshot = false
    private var currentError: SpyBikeRepositoryError?

    func start() async {}
    func stop() async {}

    func connect(vin: String) async throws {
        try throwCurrentError()
        currentConnectedVIN = vin
    }

    func disconnect() async throws {
        try throwCurrentError()
        disconnected = true
    }

    func retrySecurityHandshake() async throws {
        try throwCurrentError()
        retriedSecurityHandshake = true
    }

    func readTelemetrySnapshot() async throws {
        try throwCurrentError()
        readTelemetrySnapshot = true
    }

    func readBikeStatusSnapshot() async throws {
        try throwCurrentError()
        readBikeStatusSnapshot = true
    }

    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { .init { $0.finish() } }
    func observeConnection() async -> AsyncStream<BikeConnection> { .init { $0.finish() } }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { .init { $0.finish() } }

    func setError(_ error: SpyBikeRepositoryError) { currentError = error }
    func connectedVIN() -> String? { currentConnectedVIN }
    func didDisconnect() -> Bool { disconnected }
    func didRetrySecurityHandshake() -> Bool { retriedSecurityHandshake }
    func didReadTelemetrySnapshot() -> Bool { readTelemetrySnapshot }
    func didReadBikeStatusSnapshot() -> Bool { readBikeStatusSnapshot }

    private func throwCurrentError() throws {
        if let currentError { throw currentError }
    }
}

enum SpyBikeRepositoryError: Error, Equatable {
    case expected
}
