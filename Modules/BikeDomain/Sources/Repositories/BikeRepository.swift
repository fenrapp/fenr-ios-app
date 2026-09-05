import Foundation

public protocol BikeRepository: BikeControlRepository {
    func start() async
    func stop() async
    func connect(vin: String) async throws
    func disconnect() async throws
    func retrySecurityHandshake() async throws
    func startNewDiagnosticsCapture(vin: String) async -> Bool
    func stopDiagnosticsCapture() async -> Bool
    func readTelemetrySnapshot() async throws
    func readBikeStatusSnapshot() async throws
    func observeTelemetry() async -> AsyncStream<BikeTelemetry>
    func observeConnection() async -> AsyncStream<BikeConnection>
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent>
}

public extension BikeRepository {
    func startNewDiagnosticsCapture(vin: String) async -> Bool { false }
    func stopDiagnosticsCapture() async -> Bool { false }
    func readBikeStatusSnapshot() async throws {}
}
