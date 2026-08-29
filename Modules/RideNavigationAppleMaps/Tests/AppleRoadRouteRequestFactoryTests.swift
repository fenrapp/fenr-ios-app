import EnvironmentDomain
import MapKit
@testable import RideNavigationAppleMaps
import RideNavigationDomain
import Testing

struct AppleRoadRouteRequestFactoryTests {
    @Test("maps road preferences and requests alternatives")
    func mapsPreferences() {
        let request = AppleRoadRouteRequestFactory.make(
            origin: coordinate(latitude: 41, longitude: 2),
            destination: NavigationPlace(
                name: "Destination",
                detail: "Barcelona",
                coordinate: coordinate(latitude: 41.1, longitude: 2.1)
            ),
            preferences: RoadRoutePreferences(avoidsTolls: true, avoidsHighways: true)
        )

        #expect(request.tollPreference == .avoid)
        #expect(request.highwayPreference == .avoid)
        #expect(request.requestsAlternateRoutes)
        #expect(request.transportType == .automobile)
    }

    @Test("uses unrestricted routing by default")
    func unrestrictedDefaults() {
        let request = AppleRoadRouteRequestFactory.make(
            origin: coordinate(latitude: 41, longitude: 2),
            destination: NavigationPlace(
                name: "Destination",
                detail: "Barcelona",
                coordinate: coordinate(latitude: 41.1, longitude: 2.1)
            ),
            preferences: .init()
        )

        #expect(request.tollPreference == .any)
        #expect(request.highwayPreference == .any)
    }

    private func coordinate(latitude: Double, longitude: Double) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)!
    }
}
