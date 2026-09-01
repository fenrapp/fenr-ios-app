import Foundation
import StarkProtocol
import Testing

@Suite("Stark authentication")
struct StarkAuthenticationTests {
    @Test("PIN derivation matches known SVAG vectors")
    func pinDerivation() {
        #expect(StarkPin.derive(vin: StarkProtocolFixtures.sampleVIN) == StarkProtocolFixtures.sampleFallbackPIN)
        #expect(StarkPin.derive(vin: StarkProtocolFixtures.referenceVIN) == StarkProtocolFixtures.referenceFallbackPIN)
    }

    @Test("PIN derivation normalizes VIN and pairing date")
    func normalizedPinDerivation() {
        let pin = StarkPin.derive(
            vin: "  \(StarkProtocolFixtures.sampleVIN.lowercased())  ",
            pairingDate: StarkProtocolFixtures.formattedPairingDate
        )

        #expect(pin == StarkProtocolFixtures.sampleDatedPIN)
        #expect(pin.count == StarkPinConstants.outputDigits)
        #expect(pin.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil)
    }

    @Test("Invalid pairing date uses protocol fallback")
    func invalidPairingDateUsesFallback() {
        let pin = StarkPin.derive(vin: StarkProtocolFixtures.sampleVIN, pairingDate: "unknown")

        #expect(pin == StarkProtocolFixtures.sampleFallbackPIN)
    }

    @Test("V2 payload matches the verified protocol vector")
    func versionTwoAuthenticationPayload() throws {
        let payload = try StarkAuthenticationPayloadBuilder().buildVersionTwo(
            vin: StarkProtocolFixtures.syntheticVIN.lowercased(),
            pairingDate: "1970-01-01",
            nonce: StarkProtocolFixtures.authenticationNonce
        )

        #expect(payload == StarkProtocolFixtures.authenticationPayload)
        #expect(payload.count == StarkAuthenticationConstants.responseLength)
    }

    @Test("V2 authentication rejects an invalid nonce")
    func versionTwoAuthenticationRejectsInvalidNonce() {
        let nonce = Data(repeating: .zero, count: StarkAuthenticationConstants.nonceLength - 1)

        #expect(throws: StarkProtocolError.invalidNonceLength(
            expected: StarkAuthenticationConstants.nonceLength,
            actual: nonce.count
        )) {
            try StarkAuthenticationPayloadBuilder().buildVersionTwo(
                vin: StarkProtocolFixtures.syntheticVIN,
                pairingDate: StarkProtocolFixtures.fallbackPairingDate,
                nonce: nonce
            )
        }
    }

    @Test("V2 authentication rejects a VIN that normalizes to empty")
    func versionTwoAuthenticationRejectsEmptyNormalizedVIN() {
        #expect(throws: StarkProtocolError.invalidVIN) {
            try StarkAuthenticationPayloadBuilder().buildVersionTwo(
                vin: " - ",
                pairingDate: StarkProtocolFixtures.fallbackPairingDate,
                nonce: StarkProtocolFixtures.authenticationNonce
            )
        }
    }
}
