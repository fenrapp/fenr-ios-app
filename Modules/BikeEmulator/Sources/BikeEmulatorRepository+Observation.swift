import BikeDomain

extension BikeEmulatorRepository {
    public func startBikeDiscovery() async {
        isDiscovering = true
        await discoveredBikesHub.send([.init(vin: configuration.vin, rssi: -45)])
    }

    public func stopBikeDiscovery() async {
        guard isDiscovering else { return }
        isDiscovering = false
        await discoveredBikesHub.send([])
    }

    public func observeDiscoveredBikes() async -> AsyncStream<[DiscoveredBike]> {
        await discoveredBikesHub.stream()
    }

    public func observeTelemetry() async -> AsyncStream<BikeTelemetry> {
        await telemetryHub.stream()
    }

    public func observeConnection() async -> AsyncStream<BikeConnection> {
        await connectionHub.stream()
    }

    public func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> {
        await debugEventHub.stream()
    }

    public func observeIMU() async -> AsyncStream<BikeIMUSample> {
        await imuHub.stream()
    }

    public func startIMUMonitoring() {
        imuMonitoringLeaseCount += 1
        guard imuMonitoringLeaseCount == 1,
              lifecycleState == .started
        else { return }
        scheduleIMUUpdates(generation: generation)
    }

    public func stopIMUMonitoring() async {
        imuMonitoringLeaseCount = max(0, imuMonitoringLeaseCount - 1)
        guard imuMonitoringLeaseCount == 0 else { return }
        let task = imuUpdateTask
        imuUpdateTask?.cancel()
        await task?.value
        if imuMonitoringLeaseCount == 0 {
            imuUpdateTask = nil
        }
    }

    public func startBatteryHealthMonitoring() async throws {
        batteryHealthMonitoringLeaseCount += 1
        let date = await runtime.now()
        await publishBatteryHealth(date: date)
        if diagnostics.captureState.isRecording {
            await captureHub.replace(with: makeCaptures(date: date))
        }
    }

    public func stopBatteryHealthMonitoring() {
        batteryHealthMonitoringLeaseCount = max(0, batteryHealthMonitoringLeaseCount - 1)
    }

    public func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> {
        await batteryHealthHub.stream()
    }

    public func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> {
        await captureHub.stream()
    }
}
