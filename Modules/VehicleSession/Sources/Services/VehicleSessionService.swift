import Foundation

public protocol VehicleSessionService: Sendable {
    func observe() async -> AsyncStream<VehicleSessionSnapshot>
    func start() async
    func stop() async
    func refreshBikeStatus() async
    func calibrateDeviceMotion() async
    func setBatteryHealthMonitoringRequired(_ required: Bool, consumerID: UUID) async
}
