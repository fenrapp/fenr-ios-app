import BikeSDK
import TestSupport

enum FakeBikeTelemetryClientInvocation: Equatable, Sendable {
    case prepareChargePower(BikeSDKChargePowerTelemetryContext)
    case setChargePowerLimit(Int)
    case setChargeTarget(Int)
    case prepareBikeLock
    case setBikeLocked(Bool)
    case refreshPowerModeConfigurations
    case refreshPowerModeConfiguration(Int)
    case preparePowerModeControl(Int)
    case setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    )
    case prepareTractionControl(Int)
    case setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    )
    case refreshTractionControlConfiguration(Int)
}

actor FakeBikeTelemetryClient: BikeTelemetryClient {
    private let hub = TestEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
    private let state = FakeBikeTelemetryClientState()
    private let startControl = FakeBikeTelemetryClientInvocationControl()
    private let eventsControl = FakeBikeTelemetryClientInvocationControl()
    private let stopControl = FakeBikeTelemetryClientInvocationControl()

    func start() async {
        await state.incrementStart()
        await startControl.waitIfSuspended()
    }

    func stop() async {
        await state.incrementStop()
        await stopControl.waitIfSuspended()
    }
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
        await state.record(.prepareChargePower(context))
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
        await state.record(.setChargePowerLimit(watts))
        return BikeSDKChargePowerControlSnapshot(
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
        await state.record(.setChargeTarget(percent))
        return BikeSDKChargePowerControlSnapshot(
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

    func prepareBikeLockControl() async throws -> BikeSDKBikeLockControlSnapshot {
        await state.record(.prepareBikeLock)
        return BikeSDKBikeLockControlSnapshot(
            vcuFirmware: "1.10.1",
            isLocked: false,
            didPassNoOpWrite: true
        )
    }

    func setBikeLocked(_ isLocked: Bool) async throws -> BikeSDKBikeLockControlSnapshot {
        await state.record(.setBikeLocked(isLocked))
        return BikeSDKBikeLockControlSnapshot(
            vcuFirmware: "1.10.1",
            isLocked: isLocked,
            didPassNoOpWrite: true
        )
    }

    func refreshPowerModeConfigurations() async throws {
        await state.record(.refreshPowerModeConfigurations)
    }

    func refreshPowerModeConfiguration(mapIndex: Int) async throws {
        await state.record(.refreshPowerModeConfiguration(mapIndex))
    }

    func preparePowerModeControl(mapIndex: Int) async throws {
        await state.record(.preparePowerModeControl(mapIndex))
    }

    func setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws {
        await state.record(.setPowerModeConfiguration(
            mapIndex: mapIndex,
            horsepower: horsepower,
            regenerativeBrakingPercent: regenerativeBrakingPercent
        ))
    }

    func prepareTractionControl(mapIndex: Int) async throws {
        await state.record(.prepareTractionControl(mapIndex))
    }

    func setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws {
        await state.record(.setTractionControlConfiguration(
            mapIndex: mapIndex,
            powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent
        ))
    }

    func refreshTractionControlConfiguration(mapIndex: Int) async throws {
        await state.record(.refreshTractionControlConfiguration(mapIndex))
    }

    func events() async -> AsyncStream<BikeSDKEvent> {
        await state.incrementEventStream()
        await eventsControl.waitIfSuspended()
        return await hub.stream()
    }

    func send(_ event: BikeSDKEvent) async {
        await hub.send(event)
    }

    func startCount() async -> Int {
        await state.startCount
    }

    func stopCount() async -> Int {
        await state.stopCount
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

    func invocations() async -> [FakeBikeTelemetryClientInvocation] {
        await state.invocations
    }

    func suspendStart() async {
        await startControl.suspend()
    }

    func resumeStart() async {
        await startControl.resume()
    }

    func waitUntilStartIsSuspended() async -> Bool {
        await startControl.waitUntilSuspended()
    }

    func suspendEvents() async {
        await eventsControl.suspend()
    }

    func resumeEvents() async {
        await eventsControl.resume()
    }

    func waitUntilEventsIsSuspended() async -> Bool {
        await eventsControl.waitUntilSuspended()
    }

    func suspendStop() async {
        await stopControl.suspend()
    }

    func resumeStop() async {
        await stopControl.resume()
    }

    func waitUntilStopIsSuspended() async -> Bool {
        await stopControl.waitUntilSuspended()
    }
}

private actor FakeBikeTelemetryClientState {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var eventStreamCount = 0
    private(set) var batteryHealthStartCount = 0
    private(set) var batteryHealthStopCount = 0
    private(set) var imuStartCount = 0
    private(set) var imuStopCount = 0
    private(set) var chargePowerContext: BikeSDKChargePowerTelemetryContext?
    private(set) var invocations: [FakeBikeTelemetryClientInvocation] = []

    func incrementStart() {
        startCount += 1
    }

    func incrementStop() {
        stopCount += 1
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

    func record(_ invocation: FakeBikeTelemetryClientInvocation) {
        invocations.append(invocation)
    }
}

private actor FakeBikeTelemetryClientInvocationControl {
    private let releaseHub = TestEventHub<Void>(bufferingPolicy: .unbounded)
    private var isSuspended = false

    func suspend() {
        isSuspended = true
    }

    func waitIfSuspended() async {
        guard isSuspended else { return }
        let stream = await releaseHub.stream()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()
    }

    func resume() async {
        isSuspended = false
        await releaseHub.send(())
    }

    func waitUntilSuspended() async -> Bool {
        guard isSuspended else { return false }
        return await releaseHub.waitForSubscriber()
    }
}
