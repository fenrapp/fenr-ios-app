@testable import BikeSDK
import Testing

@Suite("Bike SDK runtime configuration")
struct BikeSDKRuntimeConfigurationTests {
    @Test("Reconnect policy is configurable")
    func reconnectPolicyIsConfigurable() {
        let expectedPolicy = BikeBLEReconnectPolicy(delays: [.seconds(2), .seconds(3)])
        let configuration = BikeSDKRuntimeConfiguration(reconnectPolicy: expectedPolicy)

        #expect(configuration.reconnectPolicy == expectedPolicy)
    }
}
