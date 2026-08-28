@testable import RideDashboard

@MainActor
final class TestDashboardDeviceBatteryMonitor: DashboardDeviceBatteryMonitoring {
    private let stream: AsyncStream<DashboardDeviceBatterySnapshot>
    private let continuation: AsyncStream<DashboardDeviceBatterySnapshot>.Continuation
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    func start() {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }

    func observe() -> AsyncStream<DashboardDeviceBatterySnapshot> {
        stream
    }

    func send(_ snapshot: DashboardDeviceBatterySnapshot) {
        continuation.yield(snapshot)
    }
}
