import Foundation
import SettingsDomain
import Testing

@Suite("Power mode names")
struct PowerModeNameTests {
    @Test("Accepts one ASCII alphanumeric word and preserves letter case")
    func acceptsValidNames() throws {
        #expect(try PowerModeName("Enduro").value == "Enduro")
        #expect(try PowerModeName("MX2").value == "MX2")
        #expect(try PowerModeName("1234567890").value == "1234567890")
    }

    @Test("Rejects empty, long, spaced, symbolic, and non-ASCII names")
    func rejectsInvalidNames() {
        #expect(throws: PowerModeNameValidationError.empty) {
            try PowerModeName("")
        }
        #expect(throws: PowerModeNameValidationError.tooLong(maximumLength: 10)) {
            try PowerModeName("12345678901")
        }
        #expect(throws: PowerModeNameValidationError.invalidCharacters) {
            try PowerModeName("Hard Enduro")
        }
        #expect(throws: PowerModeNameValidationError.invalidCharacters) {
            try PowerModeName(" ECO")
        }
        #expect(throws: PowerModeNameValidationError.invalidCharacters) {
            try PowerModeName("MX-2")
        }
        #expect(throws: PowerModeNameValidationError.invalidCharacters) {
            try PowerModeName("ECOÁ")
        }
    }

    @Test("Compares uniqueness without letter case")
    func comparesIgnoringCase() throws {
        #expect(try PowerModeName("Eco").matchesIgnoringCase(PowerModeName("ECO")))
        #expect(try !PowerModeName("Eco").matchesIgnoringCase(PowerModeName("Enduro")))
    }

    @Test("Revalidates persisted names while decoding")
    func revalidatesPersistedNames() {
        let data = Data(#"{"value":"ECO MODE"}"#.utf8)

        #expect(throws: PowerModeNameValidationError.invalidCharacters) {
            try JSONDecoder().decode(PowerModeName.self, from: data)
        }
    }
}
