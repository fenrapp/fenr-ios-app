import Foundation
import SettingsDomain
import Testing

@Suite("Power mode names")
struct PowerModeNameTests {
    @Test("Accepts names, spaces, symbols, and emoji within ten characters")
    func acceptsValidNames() throws {
        #expect(try PowerModeName("Enduro").value == "Enduro")
        #expect(try PowerModeName("Race Mode").value == "Race Mode")
        #expect(try PowerModeName("⚡️ MX 🏁").value == "⚡️ MX 🏁")
        #expect(try PowerModeName("1234567890").value == "1234567890")
        #expect(try PowerModeName("  Trail  ").value == "Trail")
    }

    @Test("Rejects empty and names longer than ten characters")
    func rejectsInvalidNames() {
        #expect(throws: PowerModeNameValidationError.empty) {
            try PowerModeName("")
        }
        #expect(throws: PowerModeNameValidationError.empty) {
            try PowerModeName("   ")
        }
        #expect(throws: PowerModeNameValidationError.tooLong(maximumLength: 10)) {
            try PowerModeName("12345678901")
        }
    }

    @Test("Compares uniqueness without letter case")
    func comparesIgnoringCase() throws {
        #expect(try PowerModeName("Eco").matchesIgnoringCase(PowerModeName("ECO")))
        #expect(try !PowerModeName("Eco").matchesIgnoringCase(PowerModeName("Enduro")))
    }

    @Test("Revalidates persisted names while decoding")
    func revalidatesPersistedNames() throws {
        let validData = Data(#"{"value":"⚡️ ECO"}"#.utf8)
        let invalidData = Data(#"{"value":"12345678901"}"#.utf8)

        #expect(try JSONDecoder().decode(PowerModeName.self, from: validData).value == "⚡️ ECO")
        #expect(throws: PowerModeNameValidationError.tooLong(maximumLength: 10)) {
            try JSONDecoder().decode(PowerModeName.self, from: invalidData)
        }
    }
}
