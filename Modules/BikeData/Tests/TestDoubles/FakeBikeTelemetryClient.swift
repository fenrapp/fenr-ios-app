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
    func readBikeStatusSnapshot() async throws {}

    func startIMUMonitoring() async throws {
        await state.incrementIMUStart()
    }

    func stopIMUMonitoring() async {
        await state.incrementIMUStop()
    }

    func startBatteryHealthMonitoring() async throws {
        await state.incrementBatteryHealthStart()
    }

    func stopBatteryHealthMonitoring() async {
        await state.incrementBatteryHealthStop()
    }

    func prepareChargePowerControl(
        context: BikeSDKChargePowerTelemetryContext
    ) async throws -> BikeSDKChargePowerControlSnapshot {
        await state.setChargePowerContext(context)
        return BikeSDKChargePowerControlSnapshot(
            vcuFirmware: "1.9.1",
            isFirmwareCompatible: true,
            readRequestHex: "00 04",
            readResponseHex: "01 04 01 50 00 E8 03 E8 03 E4 0C E4 0C",
            parsedConfig: .init(
                chargeCurrentDeciAmperes: 80,
                chargePowerWatts: 1_000,
                maximumStateOfChargeDeciPercent: 1_000,
                standardChargerMaximumPowerWatts: 3_300,
                backpackChargerMaximumPowerWatts: 3_300
            ),
            lastWriteHex: "01 04 01 50 00 E8 03 E8 03 E4 0C E4 0C",
            didPassNoOpWrite: true,
            logLines: []
        )
    }

    func setChargePowerLimit(watts: Int) async throws -> BikeSDKChargePowerControlSnapshot {
        BikeSDKChargePowerControlSnapshot(
            vcuFirmware: "1.9.1",
            isFirmwareCompatible: true,
            readRequestHex: "00 04",
            readResponseHex: "01 04 01 50 00 E8 03 E8 03 E4 0C E4 0C",
            parsedConfig: .init(
                chargeCurrentDeciAmperes: 80,
                chargePowerWatts: watts,
                maximumStateOfChargeDeciPercent: 1_000,
                standardChargerMaximumPowerWatts: 3_300,
                backpackChargerMaximumPowerWatts: 3_300
            ),
            lastWriteHex: "01 04 01",
            didPassNoOpWrite: true,
            logLines: []
        )
    }

    func setChargeTarget(percent: Int) async throws -> BikeSDKChargePowerControlSnapshot {
        BikeSDKChargePowerControlSnapshot(
            vcuFirmware: "1.9.1",
            isFirmwareCompatible: true,
            readRequestHex: "00 04",
            readResponseHex: "01 04 01 50 00 E8 03 E8 03 E4 0C E4 0C",
            parsedConfig: .init(
                chargeCurrentDeciAmperes: 80,
                chargePowerWatts: 1_000,
                maximumStateOfChargeDeciPercent: percent * 10,
                standardChargerMaximumPowerWatts: 3_300,
                backpackChargerMaximumPowerWatts: 3_300
            ),
            lastWriteHex: "01 04 01",
            didPassNoOpWrite: true,
            logLines: []
        )
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

    func imuStartCount() async -> Int {
        await state.imuStartCount
    }

    func imuStopCount() async -> Int {
        await state.imuStopCount
    }

    func batteryHealthStopCount() async -> Int {
        await state.batteryHealthStopCount
    }

    func chargePowerContext() async -> BikeSDKChargePowerTelemetryContext? {
        await state.chargePowerContext
    }
}

private actor FakeBikeTelemetryClientState {
    private(set) var startCount = 0
    private(set) var eventStreamCount = 0
    private(set) var batteryHealthStartCount = 0
    private(set) var batteryHealthStopCount = 0
    private(set) var imuStartCount = 0
    private(set) var imuStopCount = 0
    private(set) var chargePowerContext: BikeSDKChargePowerTelemetryContext?

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

    func incrementIMUStart() {
        imuStartCount += 1
    }

    func incrementIMUStop() {
        imuStopCount += 1
    }

    func setChargePowerContext(_ context: BikeSDKChargePowerTelemetryContext) {
        chargePowerContext = context
    }
}
