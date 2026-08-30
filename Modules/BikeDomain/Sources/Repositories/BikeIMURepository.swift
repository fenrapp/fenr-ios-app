public protocol BikeIMURepository: Sendable {
    func observeIMU() async -> AsyncStream<BikeIMUSample>
    func startIMUMonitoring() async throws
    func stopIMUMonitoring() async
}
