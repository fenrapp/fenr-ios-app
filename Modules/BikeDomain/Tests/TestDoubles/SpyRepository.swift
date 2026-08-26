import BikeDomain
import TestSupport

actor SpyRepository: BikeRepository {
    private let state = SpyRepositoryState()
    private let telemetry = TestEventHub<BikeTelemetry>()

    func start() async {}
    func stop() async {}

    func connect(vin: String) async throws {
        if let error = await state.error() { throw error }
        await state.setConnectedVIN(vin)
    }

    func disconnect() async throws {
        if let error = await state.error() { throw error }
        await state.setDidDisconnect()
    }

    func retrySecurityHandshake() async throws {
        if let error = await state.error() { throw error }
        await state.setDidRetrySecurityHandshake()
    }

    func readTelemetrySnapshot() async throws {
        if let error = await state.error() { throw error }
        await state.setDidReadTelemetrySnapshot()
    }

    func readBikeStatusSnapshot() async throws {
        if let error = await state.error() { throw error }
        await state.setDidReadBikeStatusSnapshot()
    }

    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { await telemetry.stream() }
    func observeConnection() async -> AsyncStream<BikeConnection> { AsyncStream { _ in } }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { AsyncStream { _ in } }

    func setError(_ error: SpyError) async { await state.setError(error) }
    func sendTelemetry(_ value: BikeTelemetry) async {
        await telemetry.waitForSubscriber()
        await telemetry.send(value)
    }
    func connectedVIN() async -> String? { await state.connectedVIN }
    func didDisconnect() async -> Bool { await state.didDisconnect }
    func didRetrySecurityHandshake() async -> Bool { await state.didRetrySecurityHandshake }
    func didReadTelemetrySnapshot() async -> Bool { await state.didReadTelemetrySnapshot }
    func didReadBikeStatusSnapshot() async -> Bool { await state.didReadBikeStatusSnapshot }
}

private actor SpyRepositoryState {
    private(set) var connectedVIN: String?
    private(set) var didDisconnect = false
    private(set) var didRetrySecurityHandshake = false
    private(set) var didReadTelemetrySnapshot = false
    private(set) var didReadBikeStatusSnapshot = false
    private var currentError: SpyError?

    func setConnectedVIN(_ vin: String) {
        connectedVIN = vin
    }

    func setDidDisconnect() {
        didDisconnect = true
    }

    func setDidRetrySecurityHandshake() {
        didRetrySecurityHandshake = true
    }

    func setDidReadTelemetrySnapshot() {
        didReadTelemetrySnapshot = true
    }

    func setDidReadBikeStatusSnapshot() {
        didReadBikeStatusSnapshot = true
    }

    func setError(_ error: SpyError) {
        currentError = error
    }

    func error() -> SpyError? {
        currentError
    }
}

enum SpyError: Error, Equatable {
    case expected
}
