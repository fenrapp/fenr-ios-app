@testable import BikeData
import Testing

@Suite("Stark bike PIN deriver")
struct StarkBikePinDeriverTests {
    @Test("Delegates VIN PIN derivation to the Stark protocol")
    func derivesExpectedPIN() {
        let deriver = StarkBikePinDeriver()

        #expect(deriver.derivePin(vin: "FENRTEST000000001") == "003368")
    }
}
