import Foundation
import MaintenanceLog
import Testing

struct MaintenanceNumberParserTests {
    @Test("Parses localized decimal and grouping separators")
    func parsesLocalizedNumbers() {
        let spanish = MaintenanceNumberParser(locale: Locale(identifier: "es_ES"))
        let english = MaintenanceNumberParser(locale: Locale(identifier: "en_US"))

        #expect(spanish.parse("12.345,6") == 12_345.6)
        #expect(english.parse("12,345.6") == 12_345.6)
    }

    @Test("Rejects empty and non-finite values")
    func rejectsInvalidNumbers() {
        let parser = MaintenanceNumberParser(locale: Locale(identifier: "en_US"))

        #expect(parser.parse(" ") == nil)
        #expect(parser.parse("not a number") == nil)
    }
}
