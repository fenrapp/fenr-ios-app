import BikeSDK
import TestSupport

actor FakeBikeTelemetryClient: BikeTelemetryClient {
    private let hub = TestEventHub<BikeSDKEvent>()
    private let state = FakeBikeTelemetryClientState()

    func start() async {
        await state.incrementStart()
    }

    func stop() async {}
    func connect(to vin: String) async throws {}
    func startBikeDiscovery() async {}
    func stopBikeDiscovery() async {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}

    func startBatteryHealthMonitoring() async throws {
        await state.incrementBatteryHealthStart()
    }

    func stopBatteryHealthMonitoring() async {
        await state.incrementBatteryHealthStop()
    }

    func events() async -> AsyncStream<BikeSDKEvent> {
        await state.incrementEventStream()
        return await hub.stream()
    }

    func send(_ event: BikeSDKEvent) async {
        await hub.send(event)
    }

    func startCount() async -> Int {
        await state.startCount
    }

    func eventStreamCount() async -> Int {
        await state.eventStreamCount
    }

    func batteryHealthStartCount() async -> Int {
        await state.batteryHealthStartCount
    }

    func batteryHealthStopCount() async -> Int {
        await state.batteryHealthStopCount
    }
}

private actor FakeBikeTelemetryClientState {
    private(set) var startCount = 0
    private(set) var eventStreamCount = 0
    private(set) var batteryHealthStartCount = 0
    private(set) var batteryHealthStopCount = 0

    func incrementStart() {
        startCount += 1
    }

    func incrementEventStream() {
        eventStreamCount += 1
    }

    func incrementBatteryHealthStart() {
        batteryHealthStartCount += 1
    }

    func incrementBatteryHealthStop() {
        batteryHealthStopCount += 1
    }
}
