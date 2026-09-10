@testable import BikeSDK
import CoreBluetooth
import StarkProtocol
import Testing

@MainActor
@Suite("Partial Bluetooth telemetry")
struct BikeBLEPartialTelemetryTests {
    @Test("Only the existing security service and characteristic are mandatory")
    func securityRemainsMandatory() {
        #expect(BikeSDKConstants.requiredServiceUUIDs == [BikeSDKConstants.bikeServiceUUID])
        #expect(BikeSDKConstants.requiredCharacteristicUUIDs(for: BikeSDKConstants.bikeServiceUUID)
            == [BikeSDKConstants.securityCharacteristicUUID])
        for service in BikeSDKConstants.serviceUUIDs where service != BikeSDKConstants.bikeServiceUUID {
            #expect(BikeSDKConstants.requiredCharacteristicUUIDs(for: service).isEmpty)
        }
    }

    @Test("Every optional dataset may be absent without blocking useful dashboard data",
           arguments: BikeSDKConstants.requiredTelemetryNotifyUUIDs.map(\.uuidString))
    func missingDataset(_ missingUUID: String) throws {
        let missing = CBUUID(string: missingUUID)
        let store = BLESessionStore()
        store.setAuthenticationState(.authenticated)
        let first = try #require(BikeSDKConstants.dashboardTelemetryUUIDs.first { $0 != missing })
        #expect(!store.markTelemetryReceived(
            characteristicUUID: first, requiredCharacteristicUUIDs: BikeSDKConstants.requiredTelemetryNotifyUUIDs
        ))
        #expect(store.markDashboardTelemetryReady())
        #expect(!store.hasReportedCompleteTelemetry)
        #expect(!store.shouldPublishSubscribedConnectionState)
        #expect(!store.markDashboardTelemetryReady())
    }

    @Test("A Bluetooth link or partial authentication never grants dashboard access",
           arguments: [BLEAuthenticationState.idle, .readingNonce, .waitingForResult, .failed])
    func requiresAuthentication(_ state: BLEAuthenticationState) {
        let store = BLESessionStore()
        store.setAuthenticationState(state)
        _ = store.markTelemetryReceived(
            characteristicUUID: BikeSDKConstants.batterySOCCharacteristicUUID,
            requiredCharacteristicUUIDs: BikeSDKConstants.requiredTelemetryNotifyUUIDs
        )
        #expect(!store.markDashboardTelemetryReady())
    }

    @Test("Map, status and firmware alone do not pretend to supply a dashboard metric")
    func requiresDashboardMetric() {
        let store = BLESessionStore()
        store.setAuthenticationState(.authenticated)
        for uuid in [StarkUUIDs.liveMap, StarkUUIDs.bikeStatus, StarkUUIDs.vcuVersions] {
            _ = store.markTelemetryReceived(
                characteristicUUID: CBUUID(nsuuid: uuid),
                requiredCharacteristicUUIDs: BikeSDKConstants.requiredTelemetryNotifyUUIDs
            )
        }
        #expect(!store.markDashboardTelemetryReady())
    }

    @Test("Optional retries are bounded and reset for the next session")
    func retriesAreBounded() {
        let store = BLESessionStore()
        let uuid = BikeSDKConstants.batterySOCCharacteristicUUID
        for operation in [BLESessionStore.TelemetryRetryOperation.descriptors, .subscription, .read] {
            #expect(store.claimTelemetryRetry(for: uuid, operation: operation))
            #expect(!store.claimTelemetryRetry(for: uuid, operation: operation))
        }
        #expect(!store.claimTelemetryRetry(for: BikeSDKConstants.securityCharacteristicUUID, operation: .read))
        #expect(!store.claimTelemetryRetry(for: BikeSDKConstants.vcuBikeConfigurationUUID, operation: .subscription))
        store.resetSession()
        #expect(store.claimTelemetryRetry(for: uuid, operation: .subscription))
        #expect(!store.hasReportedDashboardTelemetry)
    }

    @Test("Dashboard metrics are subscribed before complementary telemetry")
    func prioritizesDashboardMetric() throws {
        let store = BLESessionStore()
        store.enqueueNotificationCharacteristic(makeMutableCharacteristic(uuid: StarkUUIDs.vcuTelemetryTLV))
        store.enqueueNotificationCharacteristic(makeMutableCharacteristic(uuid: StarkUUIDs.liveSpeed))
        #expect(try #require(store.startNextNotificationCharacteristic()).uuid == CBUUID(nsuuid: StarkUUIDs.liveSpeed))
    }

    @Test("No useful telemetry has a bounded retry and a clear failure without changing authentication")
    func noTelemetryTimesOut() async {
        let store = BLESessionStore()
        store.setAuthenticationState(.authenticated)
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await hub.stream()
        let scheduler = FakeBikeBLETimeoutScheduler()
        let startup = makeTelemetryStartup(store: store, eventHub: hub, scheduler: scheduler)
        startup.start()
        await scheduler.fire()
        #expect(scheduler.hasPendingOperation)
        await scheduler.fire()
        #expect(!scheduler.hasPendingOperation)
        var iterator = stream.makeAsyncIterator()
        guard case .error = await iterator.next(), case .connection(.failed) = await iterator.next() else {
            Issue.record("No dashboard samples must end the waiting screen with a failure")
            return
        }
        #expect(store.authenticationState == .authenticated)
        #expect(!startup.received(characteristicUUID: BikeSDKConstants.batterySOCCharacteristicUUID))
    }

    @Test("One decoded metric cancels the deadline; missing complementary data does not block")
    func sampleCancelsDeadline() async throws {
        let store = BLESessionStore()
        store.setAuthenticationState(.authenticated)
        let scheduler = FakeBikeBLETimeoutScheduler()
        let startup = makeTelemetryStartup(
            store: store, eventHub: AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded), scheduler: scheduler
        )
        startup.start()
        let oldDeadline = try #require(scheduler.takePendingOperation())
        #expect(startup.received(characteristicUUID: BikeSDKConstants.batterySOCCharacteristicUUID))
        await oldDeadline()
        #expect(!scheduler.hasPendingOperation)
        #expect(store.hasReportedDashboardTelemetry)
        #expect(!store.hasReportedCompleteTelemetry)
    }

    @Test("A deadline from a previous session cannot fail a new authenticated connection")
    func staleDeadlineIsIgnored() async throws {
        let store = BLESessionStore()
        store.setAuthenticationState(.authenticated)
        let scheduler = FakeBikeBLETimeoutScheduler()
        let startup = makeTelemetryStartup(
            store: store, eventHub: AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded), scheduler: scheduler
        )
        startup.start()
        let oldDeadline = try #require(scheduler.takePendingOperation())
        store.resetSession()
        store.setAuthenticationState(.authenticated)
        startup.start()
        await oldDeadline()
        #expect(startup.received(characteristicUUID: BikeSDKConstants.batterySOCCharacteristicUUID))
        #expect(!scheduler.hasPendingOperation)
    }
}
