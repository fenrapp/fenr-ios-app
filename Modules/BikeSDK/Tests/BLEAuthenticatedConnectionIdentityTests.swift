@testable import BikeSDK
import StarkProtocol
import Testing

@MainActor
@Suite("Authenticated BLE connection identity")
struct BLEAuthenticatedConnectionIdentityTests {
    @Test("Authenticated telemetry retains its VIN when the GAP name differs")
    func authenticatedNameUsesValidatedVIN() {
        let store = BLESessionStore()
        store.setTargetVIN("fenrtest000000001")
        store.setAuthenticationState(.authenticated)

        let name = store.authenticatedConnectionName(fallback: "Simulator Host")

        #expect(name == "FENRTEST000000001")
        #expect(StarkPairingIdentity.matches(name, targetVIN: store.targetVIN))
        #expect(!StarkPairingIdentity.matches("Simulator Host", targetVIN: store.targetVIN))
    }

    @Test("An unauthenticated or reset session cannot assert the target identity")
    func unauthenticatedNameKeepsFallback() {
        let store = BLESessionStore()
        store.setTargetVIN("FENRTEST000000001")
        #expect(store.authenticatedConnectionName(fallback: "Simulator Host") == "Simulator Host")
        #expect(store.authenticatedConnectionName(fallback: nil) == nil)

        store.setAuthenticationState(.authenticated)
        #expect(store.authenticatedConnectionName(fallback: nil) == store.targetVIN)
        store.resetSession()
        #expect(store.authenticatedConnectionName(fallback: "Simulator Host") == "Simulator Host")
    }

    @Test("An invalid target cannot replace a peripheral name")
    func invalidTargetKeepsFallback() {
        let store = BLESessionStore()
        store.setTargetVIN("INVALID")
        store.setAuthenticationState(.authenticated)
        #expect(store.authenticatedConnectionName(fallback: "Simulator Host") == "Simulator Host")
        #expect(store.authenticatedConnectionName(fallback: nil) == nil)
    }
}
