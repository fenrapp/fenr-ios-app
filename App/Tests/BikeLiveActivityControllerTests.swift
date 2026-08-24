import BikeDomain
import Foundation
import SettingsDomain
import Testing

@MainActor
@Suite("Bike Live Activity controller")
struct BikeLiveActivityControllerTests {
    @Test("Does not start with default telemetry")
    func doesNotStartWithDefaultTelemetry() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(BikeTelemetry())
        await settle()

        #expect(fixture.activityClient.startCount == 0)
        #expect(await fixture.repository.monitoringStartCount() == 0)
    }

    @Test("Does not start during onboarding")
    func doesNotStartDuringOnboarding() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()

        #expect(fixture.activityClient.startCount == 0)
    }

    @Test("Does not start in foreground")
    func doesNotStartInForeground() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 3))
        await settle()

        #expect(fixture.activityClient.startCount == 0)
    }

    @Test("Starts automatically in background while charging")
    func startsInBackgroundWhileCharging() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()

        #expect(fixture.activityClient.startCount == 1)
        #expect(fixture.activityClient.lastStartedVIN == "FENRTEST000000001")
        #expect(fixture.activityClient.lastStartedState?.mode == .charging)
        #expect(await fixture.repository.monitoringStartCount() == 1)
    }

    @Test("Starts automatically in background while riding")
    func startsInBackgroundWhileRiding() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 3))
        await settle()

        #expect(fixture.activityClient.startCount == 1)
        #expect(fixture.activityClient.lastStartedState?.mode == .riding)
        #expect(fixture.activityClient.lastStartedState?.modeIndex == 3)
        #expect(await fixture.repository.monitoringStartCount() == 0)
    }

    @Test("Starts on first background transition when charging was already observed")
    func startsOnFirstBackgroundTransitionAfterChargingWasObserved() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()
        fixture.controller.setCanShowLiveActivity(true)
        await settle()

        #expect(fixture.activityClient.startCount == 1)
        #expect(fixture.activityClient.lastStartedVIN == "FENRTEST000000001")
        #expect(await fixture.repository.monitoringStartCount() == 1)
    }

    @Test("Requests activity before waiting for battery health monitoring")
    func requestsActivityBeforeBatteryHealthMonitoringCompletes() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        await fixture.repository.delayNextMonitoringStart()
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()
        fixture.controller.setCanShowLiveActivity(true)
        await settle()

        #expect(fixture.activityClient.startCount == 1)
        #expect(await fixture.repository.monitoringStartCount() == 0)
    }

    @Test("Stops delayed monitoring if charge ends before monitoring starts")
    func stopsDelayedMonitoringWhenChargeEndsBeforeMonitoringStarts() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        await fixture.repository.delayNextMonitoringStart()
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()
        fixture.controller.setCanShowLiveActivity(true)
        await settle()
        await fixture.repository.sendTelemetry(idleTelemetry(percent: 62))
        await settle()
        await settle(milliseconds: 120)

        #expect(fixture.activityClient.endCount == 1)
        #expect(await fixture.repository.monitoringStartCount() == 1)
        #expect(await fixture.repository.monitoringStopCount() == 1)
    }

    @Test("Does not duplicate activities across repeated background transitions")
    func doesNotDuplicateActivities() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()
        fixture.controller.setCanShowLiveActivity(false)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 63))
        await settle()

        #expect(fixture.activityClient.startCount == 1)
    }

    @Test("Throttles non-critical updates to thirty seconds")
    func throttlesUpdates() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()
        fixture.clock.advance(by: 29)
        await fixture.repository.sendBatteryHealth(chargingHealth(target: 90, current: 4))
        await settle()
        #expect(fixture.activityClient.updateCount == 0)

        fixture.clock.advance(by: 1)
        await fixture.repository.sendBatteryHealth(chargingHealth(target: 90, current: 5))
        await settle()
        #expect(fixture.activityClient.updateCount == 1)
    }

    @Test("Allows immediate updates for critical phase changes")
    func updatesCriticalPhaseImmediately() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()
        await fixture.repository.sendConnection(BikeConnection(state: .disconnected(reason: "Out of range")))
        await settle()

        #expect(fixture.activityClient.updateCount == 1)
        #expect(fixture.activityClient.updatedStates.last?.phase == .connectionLost)
    }

    @Test("Updates immediately when riding mode changes")
    func updatesImmediatelyWhenRidingModeChanges() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 2))
        await settle()
        fixture.clock.advance(by: 1)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 3))
        await settle()

        #expect(fixture.activityClient.updateCount == 1)
        #expect(fixture.activityClient.updatedStates.last?.modeIndex == 3)
    }

    @Test("Switches from riding to charging without duplicate activity")
    func switchesFromRidingToChargingWithoutDuplicateActivity() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 3))
        await settle()
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 73))
        await settle()

        #expect(fixture.activityClient.startCount == 1)
        #expect(fixture.activityClient.updateCount == 1)
        #expect(fixture.activityClient.updatedStates.last?.mode == .charging)
        #expect(await fixture.repository.monitoringStartCount() == 1)
    }

    @Test("Ends when riding turns off")
    func endsWhenRidingTurnsOff() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 3))
        await settle()
        await fixture.repository.sendTelemetry(idleTelemetry(percent: 72))
        await settle()

        #expect(fixture.activityClient.endCount == 1)
    }

    @Test("Ends and releases monitoring at charge target")
    func endsAtChargeTarget() async {
        let fixture = Fixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 79))
        await fixture.repository.sendBatteryHealth(chargingHealth(target: 80, current: 5))
        await settle()
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 80))
        await settle()

        #expect(fixture.activityClient.endCount == 1)
        #expect(fixture.activityClient.endedStates.last?.phase == .complete)
        #expect(await fixture.repository.monitoringStopCount() == 1)
    }

    @MainActor
    private final class Fixture {
        let repository = BikeLiveActivityRepository()
        let settingsRepository = BikeLiveActivitySettingsRepository()
        let activityClient = FakeBikeLiveActivityClient()
        let clock = FakeBikeLiveActivityClock()
        let controller: BikeLiveActivityController

        init() {
            controller = BikeLiveActivityController(
                repository: repository,
                settingsRepository: settingsRepository,
                activityClient: activityClient,
                clock: clock
            )
        }
    }
}

private actor BikeLiveActivityRepository: BikeRepository, BikeBatteryHealthRepository {
    private let telemetrySource = AsyncSource<BikeTelemetry>()
    private let batteryHealthSource = AsyncSource<BikeBatteryHealth>()
    private let connectionSource = AsyncSource<BikeConnection>()
    private var monitoringStarts = 0
    private var monitoringStops = 0
    private var delaysNextMonitoringStart = false

    func start() async {}
    func stop() async {}
    func connect(vin: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}

    func observeTelemetry() async -> AsyncStream<BikeTelemetry> {
        await telemetrySource.stream()
    }

    func observeConnection() async -> AsyncStream<BikeConnection> {
        await connectionSource.stream()
    }

    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> {
        AsyncStream { _ in }
    }

    func startBatteryHealthMonitoring() async throws {
        if delaysNextMonitoringStart {
            delaysNextMonitoringStart = false
            try? await Task.sleep(for: Constants.delayedMonitoringStartDuration)
        }
        monitoringStarts += 1
    }

    func stopBatteryHealthMonitoring() async {
        monitoringStops += 1
    }

    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> {
        await batteryHealthSource.stream()
    }

    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> {
        AsyncStream { _ in }
    }

    func sendTelemetry(_ telemetry: BikeTelemetry) async {
        await telemetrySource.send(telemetry)
    }

    func sendBatteryHealth(_ health: BikeBatteryHealth) async {
        await batteryHealthSource.send(health)
    }

    func sendConnection(_ connection: BikeConnection) async {
        await connectionSource.send(connection)
    }

    func delayNextMonitoringStart() {
        delaysNextMonitoringStart = true
    }

    func monitoringStartCount() -> Int { monitoringStarts }
    func monitoringStopCount() -> Int { monitoringStops }

    private enum Constants {
        static let delayedMonitoringStartDuration: Duration = .milliseconds(100)
    }
}

private actor BikeLiveActivitySettingsRepository: AppSettingsRepository {
    func load() async -> AppSettings { .init() }
    func save(_: AppSettings) async {}

    func observe() async -> AsyncStream<AppSettings> {
        AsyncStream { continuation in
            continuation.yield(.init())
        }
    }
}

@MainActor
private final class FakeBikeLiveActivityClient: BikeLiveActivityClient {
    private(set) var startCount = 0
    private(set) var updateCount = 0
    private(set) var endCount = 0
    private(set) var lastStartedVIN: String?
    private(set) var lastStartedState: BikeLiveActivityContentState?
    private(set) var updatedStates: [BikeLiveActivityContentState] = []
    private(set) var endedStates: [BikeLiveActivityContentState] = []
    private var active = false

    var isActive: Bool { active }

    func start(vin: String, state: BikeLiveActivityContentState) async throws {
        startCount += 1
        lastStartedVIN = vin
        lastStartedState = state
        active = true
    }

    func update(state: BikeLiveActivityContentState) async {
        updateCount += 1
        updatedStates.append(state)
    }

    func end(state: BikeLiveActivityContentState) async {
        endCount += 1
        endedStates.append(state)
        active = false
    }
}

private final class FakeBikeLiveActivityClock: BikeLiveActivityClock, @unchecked Sendable {
    private(set) var now = Date(timeIntervalSinceReferenceDate: 0)

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

private actor AsyncSource<Element: Sendable> {
    private var continuations: [UUID: AsyncStream<Element>.Continuation] = [:]

    func stream() -> AsyncStream<Element> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.remove(id) }
            }
        }
    }

    func send(_ value: Element) {
        for continuation in continuations.values {
            continuation.yield(value)
        }
    }

    private func remove(_ id: UUID) {
        continuations[id] = nil
    }
}

private func chargingTelemetry(percent: Int) -> BikeTelemetry {
    BikeTelemetry(
        vin: "FENRTEST000000001",
        batteryLevel: .known(percent: percent),
        statusFlags: .init(isCharging: true),
        lastUpdated: .testNow
    )
}

private func idleTelemetry(percent: Int) -> BikeTelemetry {
    BikeTelemetry(
        vin: "FENRTEST000000001",
        batteryLevel: .known(percent: percent),
        statusFlags: .init(isOn: false),
        lastUpdated: .testNow
    )
}

private func ridingTelemetry(percent: Int, mode: Int) -> BikeTelemetry {
    BikeTelemetry(
        vin: "FENRTEST000000001",
        batteryLevel: .known(percent: percent),
        mode: .index(mode),
        speed: .known(kmh: 48, kmhX10: 480),
        statusFlags: .init(isOn: true, isInGear: true),
        lastUpdated: .testNow
    )
}

private func chargingHealth(target: Int, current: Double) -> BikeBatteryHealth {
    BikeBatteryHealth(
        dcBusVoltage: .known(volts: 390),
        chargeState: .charging,
        chargingStatus: .init(
            requestedCurrentAmperes: current,
            reportedCurrentAmperes: current,
            maximumCurrentAmperes: 10,
            maximumPowerWatts: 3_000,
            targetCellVoltageVolts: 4.2,
            maximumStateOfChargePercent: target
        )
    )
}

private func settle() async {
    await settle(milliseconds: 20)
}

private func settle(milliseconds: Int64) async {
    try? await Task.sleep(for: .milliseconds(milliseconds))
}

private extension BikeConnection {
    static let receivingTelemetry = BikeConnection(state: .receivingTelemetry(peripheralName: "Bike"))
}

private extension Date {
    static let testNow = Date(timeIntervalSinceReferenceDate: 0)
}
