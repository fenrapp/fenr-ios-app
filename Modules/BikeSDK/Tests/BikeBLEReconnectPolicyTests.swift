@testable import BikeSDK
import Testing

@Suite("BLE reconnect policy")
struct BikeBLEReconnectPolicyTests {
    @Test("Reconnect policy applies backoff and caps attempts")
    func delayForAttempt() {
        let policy = BikeBLEReconnectPolicy(delays: [.seconds(1), .seconds(2)])

        #expect(policy.delay(forAttempt: 0) == nil)
        #expect(policy.delay(forAttempt: 1) == .seconds(1))
        #expect(policy.delay(forAttempt: 2) == .seconds(2))
        #expect(policy.delay(forAttempt: 3) == nil)
    }

    @Test("Standard reconnect policy has bounded exponential backoff")
    func standardPolicy() {
        #expect(BikeBLEReconnectPolicy.standard.delays == [
            .seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(15)
        ])
    }
}
