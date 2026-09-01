import Foundation

public protocol RideSessionService: Sendable {
    func observe() async -> AsyncStream<RideSessionSnapshot>
    func start() async
    /// Completes and flushes the active trip after all owned producers have stopped.
    func stop() async
    func persistCurrentTrip() async
    func completeCurrentTrip() async
    func flush() async
    func togglePauseCurrentTrip() async
    func resetCurrentTrip() async
    @discardableResult
    func deleteCompletedTrip(id: UUID, vin: String) async -> Bool
}

public extension RideSessionService {
    func deleteCompletedTrip(id _: UUID, vin _: String) async -> Bool {
        false
    }
}
