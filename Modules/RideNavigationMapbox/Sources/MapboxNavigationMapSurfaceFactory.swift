import MapboxMaps
import RideNavigation
import SwiftUI

@MainActor
public struct MapboxNavigationMapSurfaceFactory {
    private let fallback: RideNavigationMapSurfaceFactory

    public init(fallback: RideNavigationMapSurfaceFactory) {
        self.fallback = fallback
    }

    public func makeFactory() -> RideNavigationMapSurfaceFactory {
        RideNavigationMapSurfaceFactory { scene, onIntent, onInteraction in
            if !scene.usesOfflineMap || (scene.displayStyle == .focus && !scene.showsRoadsInFocus) {
                return fallback.make(scene: scene, onIntent: onIntent, onInteraction: onInteraction)
            }
            return AnyView(
                MapboxNavigationMapView(scene: scene, onIntent: onIntent, onInteraction: onInteraction)

            )
        }
    }

}

private struct MapboxNavigationMapView: UIViewRepresentable {
    let scene: NavigationMapScene
    let onIntent: (NavigationMapIntent) -> Void
    let onInteraction: () -> Void

    func makeCoordinator() -> MapboxNavigationCoordinator {
        MapboxNavigationCoordinator(onIntent: onIntent, onInteraction: onInteraction)
    }

    func makeUIView(context: Context) -> MapView {
        let style = StyleURI(rawValue: "mapbox://styles/mapbox/outdoors-v12")
        let map = MapView(frame: .zero, mapInitOptions: MapInitOptions(styleURI: style))
        map.gestures.options.pitchEnabled = false
        map.ornaments.options.compass.visibility = .hidden
        map.ornaments.options.scaleBar.visibility = .hidden
        // Keep the SDK attribution button and telemetry preferences available on every surface.
        map.ornaments.options.logo.position = .bottomLeft
        map.ornaments.options.attributionButton.position = .bottomRight
        map.gestures.delegate = context.coordinator
        context.coordinator.attach(map)
        return map
    }

    func updateUIView(_ map: MapView, context: Context) {
        context.coordinator.render(scene, on: map)
    }

    static func dismantleUIView(_ map: MapView, coordinator: MapboxNavigationCoordinator) {
        map.gestures.delegate = nil
        coordinator.stop()
    }
}
