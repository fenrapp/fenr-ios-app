import Foundation
@testable import RideHistory
import Testing

struct RideHistoryLocalizationTests {
    @Test("English catalog resolves symbols, interpolation, and plurals")
    func resolvesEnglishCatalog() {
        #expect(String(localized: .rideHistoryTitle) == "Ride History")
        #expect(String(localized: .rideHistoryRideCount(rideCount: 1)) == "1 ride")
        #expect(String(localized: .rideHistoryRideCount(rideCount: 3)) == "3 rides")
        #expect(String(localized: .rideHistoryRideAccessibility("Sep 2", "10:00", "5 km", "00:12", "8 Wh/km"))
            == "Ride on Sep 2 at 10:00, 5 km, 00:12, 8 Wh/km")
    }
}
