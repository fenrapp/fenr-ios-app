import MapKit
import RideNavigation
@testable import RideNavigationAppleMaps
import Testing

@MainActor
struct AppleNavigationPolylineAppearanceTests {
    @Test("Standard map uses the configured opaque appearance")
    func standardMapUsesConfiguredAppearance() throws {
        let renderer = try makeRenderer(usesFocusAppearance: false)

        #expect(renderer.strokeColor == UIColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1))
        #expect(renderer.lineWidth == 10)
    }

    @Test("Focus map ignores configured color and thickness")
    func focusMapUsesItsMonochromeAppearance() throws {
        let renderer = try makeRenderer(usesFocusAppearance: true)

        #expect(renderer.strokeColor == UIColor.label)
        #expect(renderer.lineWidth == MapRenderConstants.activeLineWidth)
    }

    @Test("Focus roads are strongly dimmed behind navigation overlays")
    func focusMapDimsBasemapContext() throws {
        let coordinator = AppleNavigationMapCoordinator(onIntent: { _ in }, onInteraction: {})
        let dimmer = FocusBasemapDimOverlay()

        let renderer = try #require(
            coordinator.mapView(MKMapView(), rendererFor: dimmer) as? FocusBasemapDimRenderer
        )

        #expect(renderer.color.cgColor.alpha == MapRenderConstants.focusBasemapDimmingOpacity)
    }

    private func makeRenderer(usesFocusAppearance: Bool) throws -> MKPolylineRenderer {
        let coordinator = AppleNavigationMapCoordinator(onIntent: { _ in }, onInteraction: {})
        coordinator.usesFocusAppearance = usesFocusAppearance
        let points = [
            CLLocationCoordinate2D(latitude: 41, longitude: 2),
            CLLocationCoordinate2D(latitude: 41.001, longitude: 2.001)
        ]
        let polyline = NavigationPolyline(coordinates: points, count: points.count)
        polyline.role = .trailActive
        polyline.appearance = NavigationMapLineAppearance(
            red: 0.1,
            green: 0.2,
            blue: 0.3,
            lineWidth: 10
        )
        return try #require(
            coordinator.mapView(MKMapView(), rendererFor: polyline) as? MKPolylineRenderer
        )
    }
}
