import Foundation
@testable import RideNavigationAppleMaps
import Testing

struct RideNavigationAppleMapsLocalizationTests {
    @Test("English accessibility copy resolves through its target catalog")
    func resolvesEnglishCatalog() {
        #expect(String(localized: .rideNavigationAppleMapsFocusMapAccessibility)
            == "Focus navigation map")
    }
}
