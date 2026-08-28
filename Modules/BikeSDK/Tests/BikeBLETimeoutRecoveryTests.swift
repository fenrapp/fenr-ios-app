@testable import BikeSDK
import CoreBluetooth
import StarkProtocol
import Testing
import TestSupport

@MainActor
@Suite("BLE timeout recovery")
struct BikeBLETimeoutRecoveryTests {
    @Test("Security watchdog fails a stalled authentication phase")
    func securityWatchdogFailsStalledPhase() async throws {
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await eventHub.stream()
        let sessionStore = BLESessionStore()
        let scheduler = FakeBikeBLETimeoutScheduler()
        sessionStore.setCharacteristic(makeMutableCharacteristic(uuid: StarkUUIDs.bikeSecurity))
        sessionStore.setAuthenticationState(.readingNonce)
        let watchdog = BikeBLESecurityWatchdog(
            sessionStore: sessionStore,
            eventEmitter: BikeBLEEventEmitter(eventHub: eventHub),
            timeoutScheduler: scheduler,
            timeoutRecoveryHandler: {}
        )

        watchdog.watch(expectedState: .readingNonce, operation: "nonce read")
        await scheduler.fire()
        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()

        #expect(sessionStore.authenticationState == .failed)
        #expect(event == .error(.operationFailed("Security operation timed out: nonce read")))
    }

    @Test("Security watchdog requests link recovery after an authentication timeout")
    func securityWatchdogRecoversStalledAuthenticationLink() async {
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let sessionStore = BLESessionStore()
        let scheduler = FakeBikeBLETimeoutScheduler()
        let recoveryRecorder = MainActorValueRecorder()
        sessionStore.setCharacteristic(makeMutableCharacteristic(uuid: StarkUUIDs.bikeSecurity))
        sessionStore.setAuthenticationState(.readingNonce)
        let watchdog = BikeBLESecurityWatchdog(
            sessionStore: sessionStore,
            eventEmitter: BikeBLEEventEmitter(eventHub: eventHub),
            timeoutScheduler: scheduler,
            timeoutRecoveryHandler: { recoveryRecorder.append(1) }
        )

        watchdog.watch(expectedState: .readingNonce, operation: "nonce read")
        await scheduler.fire()

        #expect(sessionStore.authenticationState == .failed)
        #expect(recoveryRecorder.values == [1])
    }

    @Test("Security watchdog ignores a timeout once authentication state advances")
    func securityWatchdogIgnoresAdvancedState() async {
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let sessionStore = BLESessionStore()
        let scheduler = FakeBikeBLETimeoutScheduler()
        sessionStore.setCharacteristic(makeMutableCharacteristic(uuid: StarkUUIDs.bikeSecurity))
        sessionStore.setAuthenticationState(.readingNonce)
        let watchdog = BikeBLESecurityWatchdog(
            sessionStore: sessionStore,
            eventEmitter: BikeBLEEventEmitter(eventHub: eventHub),
            timeoutScheduler: scheduler,
            timeoutRecoveryHandler: {}
        )

        watchdog.watch(expectedState: .readingNonce, operation: "nonce read")
        sessionStore.setAuthenticationState(.writingResponse)
        await scheduler.fire()

        #expect(sessionStore.authenticationState == .writingResponse)
    }

    @Test("Security watchdog ignores a timeout after the session is reset")
    func securityWatchdogIgnoresResetSession() async {
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let sessionStore = BLESessionStore()
        let scheduler = FakeBikeBLETimeoutScheduler()
        sessionStore.setCharacteristic(makeMutableCharacteristic(uuid: StarkUUIDs.bikeSecurity))
        sessionStore.setAuthenticationState(.readingNonce)
        let watchdog = BikeBLESecurityWatchdog(
            sessionStore: sessionStore,
            eventEmitter: BikeBLEEventEmitter(eventHub: eventHub),
            timeoutScheduler: scheduler,
            timeoutRecoveryHandler: {}
        )

        watchdog.watch(expectedState: .readingNonce, operation: "nonce read")
        sessionStore.resetSession()
        await scheduler.fire()

        #expect(sessionStore.authenticationState == .idle)
    }

    @Test("Subscription timeout releases the active characteristic")
    func subscriptionTimeoutReleasesQueue() async throws {
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await eventHub.stream()
        let sessionStore = BLESessionStore()
        let scheduler = FakeBikeBLETimeoutScheduler()
        let characteristic = makeMutableCharacteristic(uuid: StarkUUIDs.batterySOC)
        let coordinator = makeNotificationCoordinator(
            sessionStore: sessionStore,
            eventHub: eventHub,
            timeoutScheduler: scheduler
        )
        sessionStore.enqueueNotificationCharacteristic(characteristic)
        _ = try #require(sessionStore.startNextNotificationCharacteristic())

        await coordinator.subscriptionDidTimeOut(characteristicUUID: characteristic.uuid)
        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()

        #expect(sessionStore.activeNotificationCharacteristic == nil)
        #expect(event == .error(.operationFailed(
            "Subscription timed out: \(characteristic.uuid.uuidString)"
        )))
    }

    @Test("Timeout scheduler executes its operation")
    func timeoutSchedulerExecutesOperation() async {
        let recorder = MainActorValueRecorder()
        let scheduler = BikeBLEOperationTimeoutScheduler(duration: .zero)

        scheduler.schedule { [recorder] in
            recorder.append(1)
        }
        #expect(await waitUntil { recorder.values.count == 1 })

        #expect(recorder.values == [1])
        #expect(!scheduler.hasPendingOperation)
    }

    @Test("Security session reset cancels watchdog and pairing retry work")
    func securitySessionResetCancelsPendingWork() async {
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let sessionStore = BLESessionStore()
        let eventEmitter = BikeBLEEventEmitter(eventHub: eventHub)
        let securityScheduler = FakeBikeBLETimeoutScheduler()
        let watchdog = BikeBLESecurityWatchdog(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            timeoutScheduler: securityScheduler,
            timeoutRecoveryHandler: {}
        )
        let notificationCoordinator = makeNotificationCoordinator(
            sessionStore: sessionStore,
            eventHub: eventHub,
            timeoutScheduler: FakeBikeBLETimeoutScheduler()
        )
        let traceEmitter = makeTraceEmitter()
        let peripheralOperations = BikeBLEPeripheralOperations(traceEmitter: traceEmitter)
        let handshake = BikeBLESecurityHandshake(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            payloadBuilder: StarkAuthenticationPayloadBuilder(),
            configuration: BikeSecurityConfiguration(pairingDate: StarkPinConstants.fallbackPairingDate),
            notificationCoordinator: notificationCoordinator,
            watchdog: watchdog,
            peripheralOperations: peripheralOperations
        )
        let retryController = BikeBLEPairingRetryController(
            eventEmitter: eventEmitter,
            recoveryHandler: nil,
            policy: .init(maximumAttempts: 1, delay: .seconds(60))
        )
        let coordinator = BikeBLESecurityCoordinator(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            watchdog: watchdog,
            handshake: handshake,
            pairingRetryController: retryController,
            peripheralOperations: peripheralOperations
        )
        watchdog.watch(expectedState: .readingNonce, operation: "nonce read")
        await retryController.schedule(characteristicUUID: CBUUID(string: "1001")) { _, _ in }

        coordinator.resetSession()

        #expect(!securityScheduler.hasPendingOperation)
        #expect(!retryController.hasPendingRetry)
    }

}
