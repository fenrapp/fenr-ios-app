import StarkProtocol
import Testing

@Suite("Stark pairing identity")
struct StarkPairingIdentityTests {
    @Test("Normalizes lowercase VIN input and separators")
    func normalizesVIN() {
        let vin = StarkProtocolFixtures.sampleVIN
        let prefix = String(vin.prefix(9))
        let suffix = String(vin.dropFirst(prefix.count))

        #expect(
            StarkPairingIdentity.normalizedVIN(" \(prefix.lowercased())-\(suffix.lowercased()) ")
                == vin
        )
    }

    @Test("Accepts a standard 17 character VIN")
    func acceptsStandardVIN() {
        #expect(StarkPairingIdentity.isValidVIN(StarkProtocolFixtures.sampleVIN))
    }

    @Test("Rejects invalid length and prohibited VIN characters")
    func rejectsInvalidVIN() {
        let vin = StarkProtocolFixtures.sampleVIN
        let shortVIN = String(vin.dropLast())
        let prohibitedCharacterVIN = String(vin.dropLast()) + "I"

        #expect(!StarkPairingIdentity.isValidVIN(shortVIN))
        #expect(!StarkPairingIdentity.isValidVIN(prohibitedCharacterVIN))
    }

    @Test("Matches advertised Stark bike names against normalized targets")
    func matchesAdvertisedBikeNames() {
        let vin = StarkProtocolFixtures.sampleVIN
        let prefix = String(vin.prefix(9))
        let suffix = String(vin.dropFirst(prefix.count))
        let advertisedName = "\(prefix)-\(suffix)"

        #expect(
            StarkPairingIdentity.matches(
                advertisedName,
                targetVIN: vin
            )
        )
        #expect(
            StarkPairingIdentity.matches(
                advertisedName,
                targetVIN: suffix
            )
        )
        #expect(
            StarkPairingIdentity.matches(
                suffix,
                targetVIN: vin
            )
        )
        #expect(
            !StarkPairingIdentity.matches(
                advertisedName,
                targetVIN: String(repeating: "0", count: suffix.count)
            )
        )
        #expect(
            !StarkPairingIdentity.matches(
                advertisedName,
                targetVIN: String(suffix.suffix(4))
            )
        )
    }
}
