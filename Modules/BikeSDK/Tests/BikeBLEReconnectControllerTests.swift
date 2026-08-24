@testable import BikeSDK
import Testing
import TestSupport

@MainActor
@Suite("BLE reconnect controller")
struct BikeBLEReconnectControllerTests {
    @Test("Scheduled reconnect reports its attempt and executes once")
    func scheduledReconnectExecutesOnce() async {
        let recorder = MainActorValueRecorder()
        let controller = BikeBLEReconnectController(
            delay: BikeBLEReconnectDelay(),
            policy: .init(delays: [.zero])
        )

        let didSchedule = await controller.schedule(
            onScheduled: { attempt, maximumAttempts in
                recorder.append(attempt)
                recorder.append(maximumAttempts)
            },
            operation: {
                recorder.append(99)
            }
        )

        #expect(didSchedule)
        #expect(await waitUntil { recorder.values.count == 3 })
        #expect(recorder.values == [1, 1, 99])
        #expect(!controller.hasPendingReconnect)
    }

    @Test("Exhausted reconnect policy does not schedule work")
    func exhaustedPolicyDoesNotSchedule() async {
        let recorder = MainActorValueRecorder()
        let controller = BikeBLEReconnectController(
            delay: BikeBLEReconnectDelay(),
            policy: .init(delays: [])
        )

        let didSchedule = await controller.schedule(
            onScheduled: { _, _ in recorder.append(1) },
            operation: { recorder.append(2) }
        )

        #expect(!didSchedule)
        #expect(recorder.values.isEmpty)
        #expect(!controller.hasPendingReconnect)
    }
}
