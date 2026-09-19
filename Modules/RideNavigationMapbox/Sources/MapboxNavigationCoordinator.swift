import CoreLocation
import MapboxMaps
import RideNavigation
import UIKit

@MainActor
final class MapboxNavigationCoordinator: NSObject, @preconcurrency GestureManagerDelegate {
    private let onIntent: (NavigationMapIntent) -> Void
    private let onInteraction: () -> Void
    private weak var map: MapView?
    private var lines: PolylineAnnotationManager?
    private var guides: PolylineAnnotationManager?
    private var riderSymbols: PointAnnotationManager?
    private var loadObservation: AnyCancelable?
    private var styleObservation: AnyCancelable?
    private var points: PointAnnotationManager?
    private var circles: CircleAnnotationManager?
    private var lastScene: NavigationMapScene?
    private var style: StyleURI?

    init(onIntent: @escaping (NavigationMapIntent) -> Void, onInteraction: @escaping () -> Void) {
        self.onIntent = onIntent
        self.onInteraction = onInteraction
    }

    func attach(_ map: MapView) {
        self.map = map
        lines = map.annotations.makePolylineAnnotationManager()
        guides = map.annotations.makePolylineAnnotationManager()
        guides?.lineDasharray = [2, 2]
        points = map.annotations.makePointAnnotationManager()
        points?.iconRotationAlignment = .map
        riderSymbols = map.annotations.makePointAnnotationManager()
        riderSymbols?.iconRotationAlignment = .map
        riderSymbols?.iconAllowOverlap = true
        riderSymbols?.iconIgnorePlacement = true
        loadObservation = map.mapboxMap.onMapLoaded.observeNext { [weak self, weak map] _ in
            guard let self, let map, let scene = self.lastScene else { return }
            self.updateCamera(scene, on: map)
        }
        styleObservation = map.mapboxMap.onStyleLoaded.observe { [weak self, weak map] _ in
            guard let self, let map, let scene = self.lastScene else { return }
            self.updateFocus(scene, on: map)
        }
        circles = map.annotations.makeCircleAnnotationManager()
    }

    func stop() {
        loadObservation?.cancel()
        styleObservation?.cancel()
        guides = nil
        riderSymbols = nil
        lines = nil
        points = nil
        circles = nil
    }

    func render(_ scene: NavigationMapScene, on map: MapView) {
        let requestedStyle = scene.source.id == MapSourceDescriptor.appleHybrid.id
            ? StyleURI.satelliteStreets : StyleURI(rawValue: "mapbox://styles/mapbox/outdoors-v12")!
        if style != requestedStyle {
            style = requestedStyle
            map.mapboxMap.styleURI = requestedStyle
        }
        if lastScene?.displayStyle != scene.displayStyle { updateFocus(scene, on: map) }
        if lastScene?.polylines != scene.polylines || lastScene?.displayStyle != scene.displayStyle {
            let annotations = scene.polylines.filter { $0.points.count > 1 }.map { line in
                var annotation = PolylineAnnotation(id: line.id, lineCoordinates: line.points.map(\.clCoordinate))
                let appearance = line.appearance
                annotation.lineColor = StyleColor(UIColor(
                    red: appearance?.red ?? 0, green: appearance?.green ?? 0.6,
                    blue: appearance?.blue ?? 1, alpha: 1
                ))
                if scene.displayStyle == .focus {
                    annotation.lineColor = StyleColor(Self.focusColor(line.role))
                }
                annotation.lineOpacity = line.role == .trailFuture ? Constants.futureOpacity : 1
                annotation.lineWidth = appearance?.lineWidth ?? Constants.lineWidth
                return annotation
            }
            let guideIDs = Set(scene.polylines.filter { $0.role == .rejoinGuide }.map(\.id))
            lines?.annotations = annotations.filter { !guideIDs.contains($0.id) }
            guides?.annotations = annotations.filter { guideIDs.contains($0.id) }
        }
        if lastScene?.markers != scene.markers || lastScene?.directionalIndicators != scene.directionalIndicators {
            points?.annotations = scene.markers.map { marker in
                var annotation = PointAnnotation(id: marker.id, coordinate: marker.coordinate.clCoordinate)
                annotation.textField = marker.title
                annotation.textColor = StyleColor(.label)
                annotation.textHaloColor = StyleColor(.systemBackground)
                annotation.textHaloWidth = Constants.haloWidth
                annotation.textSize = Constants.labelSize
                annotation.tapHandler = { [weak self] _ in
                    self?.onIntent(.selectMarker(marker.id))
                    return true
                }
                return annotation
            } + scene.directionalIndicators.map { indicator in
                var annotation = PointAnnotation(id: indicator.id, coordinate: indicator.coordinate.clCoordinate)
                annotation.image = UIImage(systemName: "location.north.fill").map {
                    PointAnnotation.Image(image: $0, name: "fenr-direction")
                }
                annotation.iconRotate = indicator.rotationDegrees
                annotation.iconSize = Constants.directionSize
                return annotation
            }
        }
        updateRider(scene)
        if lastScene?.camera != scene.camera || (scene.camera == .automatic && lastScene?.userCoordinate == nil) {
            updateCamera(scene, on: map)
        }
        lastScene = scene
    }

    private func updateRider(_ scene: NavigationMapScene) {
        if let coordinate = scene.userCoordinate {
            var rider = CircleAnnotation(id: "fenr-rider", centerCoordinate: coordinate.clCoordinate)
            rider.circleColor = StyleColor(.systemBlue)
            rider.circleRadius = Constants.riderRadius
            rider.circleStrokeColor = StyleColor(.white)
            rider.circleStrokeWidth = Constants.riderStroke
            var rings = [CircleAnnotation]()
            if scene.showsCompassRing {
                var ring = CircleAnnotation(id: "fenr-compass-ring", centerCoordinate: coordinate.clCoordinate)
                ring.circleRadius = Constants.compassRadius
                ring.circleColor = StyleColor(.clear)
                ring.circleStrokeColor = StyleColor(.secondaryLabel)
                ring.circleStrokeWidth = Constants.compassStroke
                rings.append(ring)
            }
            circles?.annotations = rings + [rider]
            if let heading = scene.userHeadingDegrees {
                var arrow = PointAnnotation(id: "fenr-heading", coordinate: coordinate.clCoordinate)
                arrow.image = UIImage(systemName: "location.north.fill").map {
                    PointAnnotation.Image(image: $0.withTintColor(.systemBlue), name: "fenr-heading")
                }
                arrow.iconRotate = heading
                arrow.iconSize = Constants.headingSize
                riderSymbols?.annotations = [arrow]
            } else {
                riderSymbols?.annotations = []
            }
        } else {
            circles?.annotations = []
            riderSymbols?.annotations = []
        }
    }

    private func updateFocus(_ scene: NavigationMapScene, on map: MapView) {
        guard let lines, map.mapboxMap.layerExists(withId: lines.layerId) else { return }
        if map.mapboxMap.layerExists(withId: Constants.focusLayer) {
            try? map.mapboxMap.removeLayer(withId: Constants.focusLayer)
        }
        guard scene.displayStyle == .focus else { return }
        var layer = BackgroundLayer(id: Constants.focusLayer)
        layer.backgroundColor = .constant(StyleColor(.systemBackground))
        layer.backgroundOpacity = .constant(Constants.focusOpacity)
        try? map.mapboxMap.addLayer(layer, layerPosition: .below(lines.layerId))
    }

    private static func focusColor(_ role: NavigationMapPolylineRole) -> UIColor {
        switch role {
        case .planned, .trailActive, .approach, .rejoinGuide: .label
        case .trailFuture, .recorded: .secondaryLabel
        case .trailCompleted, .completed: .tertiaryLabel
        }
    }

    func gestureManager(_ gestureManager: GestureManager, didBegin gestureType: GestureType) {
        onInteraction()
        onIntent(.userMovedCamera)
    }

    func gestureManager(_ gestureManager: GestureManager, didEnd gestureType: GestureType, willAnimate: Bool) {
        if !willAnimate { rememberViewport() }
    }
    func gestureManager(_ gestureManager: GestureManager, didEndAnimatingFor gestureType: GestureType) {
        rememberViewport()
    }

    private func rememberViewport() {
        guard let map else { return }
        let camera = map.mapboxMap.cameraState
        guard let center = NavigationMapCoordinate(
            latitudeDegrees: camera.center.latitude, longitudeDegrees: camera.center.longitude
        ), let viewport = NavigationMapViewport(
            center: center,
            visibleHeightMeters: Constants.worldMeters * cos(camera.center.latitude * .pi / 180)
                / (Constants.tileSize * pow(2, camera.zoom)) * map.bounds.height,
            bearingDegrees: camera.bearing
        ) else { return }
        onIntent(.rememberViewport(viewport))
    }

    private func updateCamera(_ scene: NavigationMapScene, on map: MapView) {
        switch scene.camera {
        case .automatic:
            if let coordinate = scene.userCoordinate {
                map.mapboxMap.setCamera(to: CameraOptions(center: coordinate.clCoordinate, zoom: Constants.initialZoom))
            }
        case .follow(let coordinate, let heading):
            map.mapboxMap.setCamera(to: CameraOptions(
                center: coordinate.clCoordinate, zoom: Constants.followZoom, bearing: heading ?? 0, pitch: 0
            ))
        case .overview(let coordinates):
            if let camera = try? map.mapboxMap.camera(
                for: coordinates.map(\.clCoordinate), camera: CameraOptions(bearing: 0, pitch: 0),
                coordinatesPadding: Constants.overviewInsets, maxZoom: Constants.followZoom, offset: nil
            ) {
                map.mapboxMap.setCamera(to: camera)
            }
        case .viewport(let viewport):
            let zoom = log2(Constants.worldMeters * cos(viewport.center.latitudeDegrees * .pi / 180)
                * max(1, map.bounds.height) / (Constants.tileSize * viewport.visibleHeightMeters))
            map.mapboxMap.setCamera(to: CameraOptions(
                center: viewport.center.clCoordinate, zoom: zoom, bearing: viewport.bearingDegrees, pitch: 0
            ))
        case .userControlled: break
        }
    }

    private enum Constants {
        static let focusLayer = "fenr-focus-background"
        static let focusOpacity = 0.82
        static let futureOpacity = 0.7
        static let compassRadius = 24.0
        static let compassStroke = 1.0
        static let headingSize = 1.5
        static let worldMeters = 40_075_016.6856
        static let tileSize = 512.0
        static let lineWidth = 7.0
        static let labelSize = 14.0
        static let haloWidth = 2.0
        static let directionSize = 0.7
        static let riderRadius = 7.0
        static let riderStroke = 3.0
        static let initialZoom = 13.0
        static let followZoom = 16.0
        static let overviewInsets = UIEdgeInsets(top: 100, left: 60, bottom: 140, right: 60)
    }
}

extension NavigationMapCoordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitudeDegrees, longitude: longitudeDegrees)
    }
}
