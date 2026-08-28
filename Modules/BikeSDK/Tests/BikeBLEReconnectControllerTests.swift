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
            policy: .init(delays: [.zero]),
            connectionStabilityPeriod: .zero
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
            policy: .init(delays: []),
            connectionStabilityPeriod: .zero
        )

        let didSchedule = await controller.schedule(
            onScheduled: { _, _ in recorder.append(1) },
            operation: { recorder.append(2) }
        )

        #expect(!didSchedule)
        #expect(recorder.values.isEmpty)
        #expect(!controller.hasPendingReconnect)
    }

    @Test("Backoff resets only after telemetry remains stable")
    func stableTelemetryResetsBackoff() async throws {
        let recorder = MainActorValueRecorder()
        let controller = BikeBLEReconnectController(
            delay: BikeBLEReconnectDelay(),
            policy: .init(delays: [.seconds(60), .seconds(60), .seconds(60)]),
            connectionStabilityPeriod: .milliseconds(20)
        )
        let schedule = {
            await controller.schedule(
                onScheduled: { attempt, _ in recorder.append(attempt) },
                operation: {}
            )
        }

        #expect(await schedule())
        controller.cancelPending()
        #expect(await schedule())
        #expect(recorder.values == [1, 2])

        controller.markConnectionReady()
        #expect(await schedule())
        #expect(recorder.values == [1, 2, 3])

        controller.cancelPending()
        controller.markConnectionReady()
        try await Task.sleep(for: .milliseconds(30))
        #expect(await schedule())
        #expect(recorder.values == [1, 2, 3, 1])
        controller.cancelPending()
    }
}
