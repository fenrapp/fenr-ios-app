import MapKit
import RideNavigation
import SwiftUI

@MainActor
public struct AppleNavigationMapSurfaceFactory {
    public init() {}

    public func makeFactory() -> RideNavigationMapSurfaceFactory {
        RideNavigationMapSurfaceFactory { scene, onIntent, onInteraction in
            if scene.displayStyle == .focus {
                return AnyView(
                    FocusNavigationMapView(
                        scene: scene,
                        renderer: FocusNavigationRenderer(pathCache: FocusNavigationPathCache()),
                        onIntent: onIntent,
                        onInteraction: onInteraction
                    )
                )
            }
            return AnyView(
                AppleNavigationMapView(
                    scene: scene,
                    onIntent: onIntent,
                    onInteraction: onInteraction
                )
            )
        }
    }
}

private struct AppleNavigationMapView: UIViewRepresentable {
    let scene: NavigationMapScene
    let onIntent: (NavigationMapIntent) -> Void
    let onInteraction: () -> Void

    func makeCoordinator() -> AppleNavigationMapCoordinator {
        AppleNavigationMapCoordinator(onIntent: onIntent, onInteraction: onInteraction)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsCompass = false
        map.showsScale = false
        map.pointOfInterestFilter = .excludingAll
        map.isPitchEnabled = false
        map.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MapRenderConstants.markerReuseID
        )
        map.register(
            RiderAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MapRenderConstants.riderReuseID
        )
        map.register(
            DirectionalAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MapRenderConstants.directionalIndicatorReuseID
        )
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(AppleNavigationMapCoordinator.didInteract)
        )
        tap.cancelsTouchesInView = false
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.onIntent = onIntent
        context.coordinator.onInteraction = onInteraction
        updateSource(on: map, coordinator: context.coordinator)
        updatePolylines(on: map, coordinator: context.coordinator)
        updateMarkers(on: map, coordinator: context.coordinator)
        updateDirectionalIndicators(on: map, coordinator: context.coordinator)
        context.coordinator.updateRider(
            on: map,
            coordinate: scene.userCoordinate?.clCoordinate,
            headingDegrees: scene.userHeadingDegrees
        )
        updateCamera(on: map, coordinator: context.coordinator)
    }

    private func updateSource(on map: MKMapView, coordinator: AppleNavigationMapCoordinator) {
        guard coordinator.renderedSource != scene.source else { return }
        configure(map, for: scene.source)
        coordinator.renderedSource = scene.source
    }

    private func updatePolylines(on map: MKMapView, coordinator: AppleNavigationMapCoordinator) {
        let incoming = Dictionary(uniqueKeysWithValues: scene.polylines.map {
            ($0.id, NavigationPolylineRenderSignature(role: $0.role, revision: $0.revision))
        })
        let removedOrChanged = coordinator.renderedPolylineSignatures.compactMap { id, signature in
            incoming[id] == signature ? nil : id
        }
        let overlaysToRemove = removedOrChanged.compactMap {
            coordinator.renderedPolylineOverlays.removeValue(forKey: $0)
        }
        map.removeOverlays(overlaysToRemove)
        for id in removedOrChanged {
            coordinator.renderedPolylineSignatures[id] = nil
        }
        let polylines = scene.polylines.sorted { $0.role.renderPriority < $1.role.renderPriority }
        for line in polylines where line.points.count > 1
            && coordinator.renderedPolylineSignatures[line.id] != incoming[line.id] {
            let coordinates = line.points.map(\.clCoordinate)
            let polyline = NavigationPolyline(coordinates: coordinates, count: coordinates.count)
            polyline.id = line.id
            polyline.role = line.role
            insert(polyline, on: map)
            coordinator.renderedPolylineOverlays[line.id] = polyline
            coordinator.renderedPolylineSignatures[line.id] = incoming[line.id]
        }
    }

    private func insert(_ polyline: NavigationPolyline, on map: MKMapView) {
        if let higherOverlay = map.overlays.compactMap({ $0 as? NavigationPolyline }).first(
            where: { $0.role.renderPriority > polyline.role.renderPriority }
        ) {
            map.insertOverlay(polyline, below: higherOverlay)
        } else {
            map.addOverlay(polyline)
        }
    }

    private func updateMarkers(on map: MKMapView, coordinator: AppleNavigationMapCoordinator) {
        guard coordinator.renderedMarkers != scene.markers else { return }
        map.removeAnnotations(map.annotations.compactMap { $0 as? NavigationAnnotation })
        for marker in scene.markers {
            map.addAnnotation(
                NavigationAnnotation(
                    coordinate: marker.coordinate.clCoordinate,
                    title: marker.title,
                    role: marker.role
                )
            )
        }
        coordinator.renderedMarkers = scene.markers
    }

    private func updateDirectionalIndicators(on map: MKMapView, coordinator: AppleNavigationMapCoordinator) {
        guard coordinator.renderedDirectionalIndicators != scene.directionalIndicators else { return }
        map.removeAnnotations(map.annotations.compactMap { $0 as? DirectionalAnnotation })
        for indicator in scene.directionalIndicators {
            map.addAnnotation(
                DirectionalAnnotation(
                    id: indicator.id,
                    coordinate: indicator.coordinate.clCoordinate,
                    rotationDegrees: indicator.rotationDegrees
                )
            )
        }
        coordinator.renderedDirectionalIndicators = scene.directionalIndicators
    }

    private func updateCamera(on map: MKMapView, coordinator: AppleNavigationMapCoordinator) {
        let renderState = AppleNavigationMapCameraRenderState(scene: scene)
        guard coordinator.renderedCamera != renderState else { return }
        coordinator.renderedCamera = renderState

        switch renderState.camera {
        case .automatic:
            if let coordinate = renderState.userCoordinate?.clCoordinate {
                let region = MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: Constants.automaticRegionMeters,
                    longitudinalMeters: Constants.automaticRegionMeters
                )
                map.setRegion(region, animated: false)
            }
        case .follow(let coordinate, let heading):
            let camera = MKMapCamera(
                lookingAtCenter: coordinate.clCoordinate,
                fromDistance: Constants.followDistance,
                pitch: Constants.followPitch,
                heading: heading ?? .zero
            )
            map.setCamera(camera, animated: false)
        case .overview(let coordinates):
            guard !coordinates.isEmpty else { break }
            let mapRect = coordinates.map(\.clCoordinate).reduce(MKMapRect.null) { rect, coordinate in
                rect.union(MKMapRect(origin: MKMapPoint(coordinate), size: MKMapSize(width: 1, height: 1)))
            }
            map.setVisibleMapRect(
                mapRect,
                edgePadding: Constants.routeInsets,
                animated: true
            )
        case .userControlled:
            break
        }
    }

    private func configure(_ map: MKMapView, for source: MapSourceDescriptor) {
        if source.id == MapSourceDescriptor.appleHybrid.id {
            let configuration = MKHybridMapConfiguration(elevationStyle: .flat)
            configuration.pointOfInterestFilter = .excludingAll
            map.preferredConfiguration = configuration
        } else {
            let configuration = MKStandardMapConfiguration(elevationStyle: .flat)
            configuration.pointOfInterestFilter = .excludingAll
            map.preferredConfiguration = configuration
        }
    }

    private enum Constants {
        static let followDistance: CLLocationDistance = 450
        static let followPitch: CGFloat = 0
        static let automaticRegionMeters: CLLocationDistance = 1_600
        static let routeInsets = UIEdgeInsets(top: 100, left: 120, bottom: 140, right: 120)
    }
}

struct AppleNavigationMapCameraRenderState: Equatable {
    let camera: NavigationMapCamera
    let userCoordinate: NavigationMapCoordinate?

    init(scene: NavigationMapScene) {
        camera = scene.camera
        if case .automatic = scene.camera {
            userCoordinate = scene.userCoordinate
        } else {
            userCoordinate = nil
        }
    }
}
