@testable import BikeSDK
import CoreBluetooth
import Testing
import TestSupport

@MainActor
@Suite("BLE pairing retry controller")
struct BikeBLEPairingRetryControllerTests {
    @Test("Completed retry releases its task")
    func completedRetryReleasesTask() async {
        let recorder = MainActorValueRecorder()
        let controller = makeController(
            policy: .init(maximumAttempts: 1, delay: .zero)
        )

        await controller.schedule(characteristicUUID: CBUUID(string: "1001")) { attempt, _ in
            recorder.append(attempt)
        }

        #expect(await waitUntil { recorder.values == [1] })
        #expect(!controller.hasPendingRetry)
    }

    @Test("Reset cancels a pending retry and resets its attempt budget")
    func resetCancelsPendingRetry() async {
        let controller = makeController(
            policy: .init(maximumAttempts: 1, delay: .seconds(60))
        )

        await controller.schedule(characteristicUUID: CBUUID(string: "1001")) { _, _ in }
        #expect(controller.hasPendingRetry)

        controller.reset()

        #expect(!controller.hasPendingRetry)
        await controller.schedule(characteristicUUID: CBUUID(string: "1001")) { _, _ in }
        #expect(controller.hasPendingRetry)
        controller.reset()
    }

    @Test("Exhausted retries request recovery only once")
    func exhaustedRetriesRecoverOnce() async {
        let recoveryRecorder = MainActorValueRecorder()
        let controller = makeController(
            policy: .init(maximumAttempts: 1, delay: .seconds(60)),
            recoveryHandler: { recoveryRecorder.append(1) }
        )
        let uuid = CBUUID(string: "1001")

        await controller.schedule(characteristicUUID: uuid) { _, _ in }
        await controller.schedule(characteristicUUID: uuid) { _, _ in }
        await controller.schedule(characteristicUUID: uuid) { _, _ in }

        #expect(recoveryRecorder.values == [1])
        #expect(!controller.hasPendingRetry)
    }

    private func makeController(
        policy: BikeBLEPairingRetryPolicy,
        recoveryHandler: (@MainActor @Sendable () async -> Void)? = nil
    ) -> BikeBLEPairingRetryController {
        BikeBLEPairingRetryController(
            eventEmitter: BikeBLEEventEmitter(
                eventHub: AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
            ),
            recoveryHandler: recoveryHandler,
            policy: policy
        )
    }
}
