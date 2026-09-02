@testable import BatteryHealth
import Foundation
import Testing

struct BatteryHealthLocalizationTests {
    @Test("English catalog resolves symbols and interpolation")
    func resolvesEnglishCatalog() {
        #expect(String(localized: .batteryHealthTitle) == "Battery Health")
        #expect(String(localized: .batteryHealthDatasetCapturedBytes(200)) == "Captured 200 B")
        #expect(
            String(localized: .batteryHealthChargeControlStatusConfirmingPower(1_500))
                == "Confirming \(1_500.formatted()) W"
        )
        #expect(
            String(localized: .batteryHealthCellAccessibilityBalancing(2, "3.8286 V", "-12 mV"))
                == "Cell 2, 3.8286 V, -12 mV, balancing"
        )
    }
}
