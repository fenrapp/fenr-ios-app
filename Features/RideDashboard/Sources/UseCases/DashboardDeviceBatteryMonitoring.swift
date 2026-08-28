public protocol DashboardDeviceBatteryMonitoring: AnyObject {
    @MainActor func start()
    @MainActor func stop()
    @MainActor func observe() -> AsyncStream<DashboardDeviceBatterySnapshot>
}
