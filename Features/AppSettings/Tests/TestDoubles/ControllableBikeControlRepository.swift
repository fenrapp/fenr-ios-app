import BikeDomain
import Foundation
import TestSupport

actor ControllableBikeControlRepository: BikeRepository {
    enum RefreshBehavior: Sendable {
        case success
        case failure
        case suspended
    }

    enum RefreshError: LocalizedError {
        case failed

        var errorDescription: String? { "Refresh failed" }
    }

    private let connection: BikeConnection
    private let refreshStartedHub = TestEventHub<Void>(bufferingPolicy: .unbounded)
    private let refreshCancelledHub = TestEventHub<Void>(bufferingPolicy: .unbounded)
    private let refreshBehavior: RefreshBehavior
    private var refreshWaiter: (id: UUID, continuation: CheckedContinuation<Void, any Error>)?

    init(
        connection: BikeConnection = .init(state: .receivingTelemetry(peripheralName: "Test bike")),
        refreshBehavior: RefreshBehavior = .success
    ) {
        self.connection = connection
        self.refreshBehavior = refreshBehavior
    }

    func start() {}
    func stop() {}
    func connect(vin _: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}

    func observeTelemetry() -> AsyncStream<BikeTelemetry> {
        .init { $0.finish() }
    }

    func observeConnection() -> AsyncStream<BikeConnection> {
        .init { continuation in
            continuation.yield(connection)
            continuation.finish()
        }
    }

    func observeDebugEvents() -> AsyncStream<BikeDebugEvent> {
        .init { $0.finish() }
    }

    func refreshPowerModeConfigurations() async throws {
        await refreshStartedHub.send(())
        switch refreshBehavior {
        case .success:
            return
        case .failure:
            throw RefreshError.failed
        case .suspended:
            let identifier = UUID()
            do {
                try await withTaskCancellationHandler {
                    try Task.checkCancellation()
                    try await withCheckedThrowingContinuation { continuation in
                        refreshWaiter = (identifier, continuation)
                    }
                } onCancel: {
                    Task { await self.cancelRefresh(identifier: identifier) }
                }
            } catch {
                if error is CancellationError {
                    await refreshCancelledHub.send(())
                }
                throw error
            }
        }
    }

    func observeRefreshStarts() async -> AsyncStream<Void> {
        await refreshStartedHub.stream()
    }

    func observeRefreshCancellations() async -> AsyncStream<Void> {
        await refreshCancelledHub.stream()
    }

    func releaseRefresh() {
        guard let refreshWaiter else { return }
        self.refreshWaiter = nil
        refreshWaiter.continuation.resume()
    }

    private func cancelRefresh(identifier: UUID) async {
        guard let refreshWaiter, refreshWaiter.id == identifier else { return }
        self.refreshWaiter = nil
        refreshWaiter.continuation.resume(throwing: CancellationError())
    }
}
