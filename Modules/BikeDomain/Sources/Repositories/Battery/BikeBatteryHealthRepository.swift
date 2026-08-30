public protocol BikeBatteryHealthRepository: Sendable {
    func startBatteryHealthMonitoring() async throws
    func stopBatteryHealthMonitoring() async
    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth>
    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture>
}
