public protocol RideSessionService: Sendable {
    func observe() async -> AsyncStream<RideSessionSnapshot>
    func start() async
    func stop() async
    func persistCurrentTrip() async
    func completeCurrentTrip() async
    func flush() async
    func togglePauseCurrentTrip() async
    func resetCurrentTrip() async
}
