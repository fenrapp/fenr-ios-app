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
            timeoutScheduler: scheduler
        )

        watchdog.watch(expectedState: .readingNonce, operation: "nonce read")
        await scheduler.fire()
        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()

        #expect(sessionStore.authenticationState == .failed)
        #expect(event == .error(.operationFailed("Security operation timed out: nonce read")))
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
            timeoutScheduler: scheduler
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
            timeoutScheduler: scheduler
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
    }

}
