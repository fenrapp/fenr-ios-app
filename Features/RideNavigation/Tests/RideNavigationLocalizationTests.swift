import Foundation
@testable import RideNavigation
import Testing

struct RideNavigationLocalizationTests {
    @Test("English catalog resolves symbols, interpolation, and plurals")
    func resolvesEnglishCatalog() {
        #expect(String(localized: .rideNavigationTitle) == "Ride Navigation")
        #expect(String(localized: .rideNavigationSavedRouteCount(routeCount: 1)) == "1 saved route")
        #expect(String(localized: .rideNavigationSavedRouteCount(routeCount: 2)) == "2 saved routes")
        #expect(String(localized: .rideNavigationDistanceRemaining("2 km")) == "2 km remaining")
    }
}
