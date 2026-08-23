import StarkProtocol
import Testing

@Suite("Stark pairing identity")
struct StarkPairingIdentityTests {
    @Test("Normalizes lowercase VIN input and separators")
    func normalizesVIN() {
        #expect(
            StarkPairingIdentity.normalizedVIN(" 1hg-cm82633a004352 ")
                == "1HGCM82633A004352"
        )
    }

    @Test("Accepts a standard 17 character VIN")
    func acceptsStandardVIN() {
        #expect(StarkPairingIdentity.isValidVIN("1HGCM82633A004352"))
    }

    @Test("Rejects invalid length and prohibited VIN characters")
    func rejectsInvalidVIN() {
        #expect(!StarkPairingIdentity.isValidVIN("1HGCM82633A00435"))
        #expect(!StarkPairingIdentity.isValidVIN("1HGCM826I3A004352"))
    }
}
