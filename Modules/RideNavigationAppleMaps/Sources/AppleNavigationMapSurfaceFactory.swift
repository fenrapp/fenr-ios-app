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

    func makeCoordinator() -> Coordinator {
        Coordinator(onIntent: onIntent, onInteraction: onInteraction)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsCompass = false
        map.showsScale = false
        map.pointOfInterestFilter = .excludingAll
        map.isPitchEnabled = false
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: Constants.markerReuseID)
        map.register(RiderAnnotationView.self, forAnnotationViewWithReuseIdentifier: Constants.riderReuseID)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didInteract))
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
        context.coordinator.updateRider(
            on: map,
            coordinate: scene.userCoordinate?.clCoordinate,
            headingDegrees: scene.userHeadingDegrees
        )
        updateCamera(on: map, coordinator: context.coordinator)
    }

    private func updateSource(on map: MKMapView, coordinator: Coordinator) {
        guard coordinator.renderedSource != scene.source else { return }
        configure(map, for: scene.source)
        coordinator.renderedSource = scene.source
    }

    private func updatePolylines(on map: MKMapView, coordinator: Coordinator) {
        guard coordinator.renderedPolylines != scene.polylines else { return }
        map.removeOverlays(map.overlays)
        for line in scene.polylines where line.points.count > 1 {
            let coordinates = line.points.map(\.clCoordinate)
            let polyline = NavigationPolyline(coordinates: coordinates, count: coordinates.count)
            polyline.role = line.role
            map.addOverlay(polyline)
        }
        coordinator.renderedPolylines = scene.polylines
    }

    private func updateMarkers(on map: MKMapView, coordinator: Coordinator) {
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

    private func updateCamera(on map: MKMapView, coordinator: Coordinator) {
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

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onIntent: (NavigationMapIntent) -> Void
        var onInteraction: () -> Void
        var renderedSource: MapSourceDescriptor?
        var renderedPolylines: [NavigationMapPolyline] = []
        var renderedMarkers: [NavigationMapMarker] = []
        var renderedCamera: AppleNavigationMapCameraRenderState?
        private var riderAnnotation: RiderAnnotation?

        init(
            onIntent: @escaping (NavigationMapIntent) -> Void,
            onInteraction: @escaping () -> Void
        ) {
            self.onIntent = onIntent
            self.onInteraction = onInteraction
        }

        @objc func didInteract() {
            onInteraction()
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? NavigationPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: line)
            renderer.lineCap = .round
            renderer.lineJoin = .round
            switch line.role {
            case .planned:
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = Constants.plannedLineWidth
            case .completed:
                renderer.strokeColor = .systemCyan
                renderer.lineWidth = Constants.completedLineWidth
            case .recorded:
                renderer.strokeColor = .systemRed
                renderer.lineWidth = Constants.recordedLineWidth
            case .approach:
                renderer.strokeColor = .systemTeal
                renderer.lineWidth = Constants.plannedLineWidth
            case .rejoinGuide:
                renderer.strokeColor = .white
                renderer.lineWidth = Constants.rejoinLineWidth
                renderer.lineDashPattern = [2, 8]
            }
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let rider = annotation as? RiderAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: Constants.riderReuseID,
                    for: rider
                ) as? RiderAnnotationView
                view?.update(
                    headingDegrees: rider.headingDegrees,
                    mapHeadingDegrees: mapView.camera.heading
                )
                return view
            }
            guard let marker = annotation as? NavigationAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: Constants.markerReuseID,
                for: marker
            ) as? MKMarkerAnnotationView
            view?.markerTintColor = switch marker.role {
            case .start: .systemGreen
            case .finish: .systemRed
            case .waypoint: .systemOrange
            case .participant: .systemPurple
            }
            view?.glyphImage = UIImage(systemName: marker.role == .participant ? "person.fill" : "flag.fill")
            view?.displayPriority = .required
            return view
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            guard hasActiveGesture(in: mapView) else { return }
            onInteraction()
            onIntent(.userMovedCamera)
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            guard let riderAnnotation,
                  let view = mapView.view(for: riderAnnotation) as? RiderAnnotationView else { return }
            view.update(
                headingDegrees: riderAnnotation.headingDegrees,
                mapHeadingDegrees: mapView.camera.heading
            )
        }

        func updateRider(
            on mapView: MKMapView,
            coordinate: CLLocationCoordinate2D?,
            headingDegrees: Double?
        ) {
            guard let coordinate else {
                if let riderAnnotation {
                    mapView.removeAnnotation(riderAnnotation)
                    self.riderAnnotation = nil
                }
                return
            }
            let annotation: RiderAnnotation
            if let riderAnnotation {
                annotation = riderAnnotation
                riderAnnotation.coordinate = coordinate
            } else {
                annotation = RiderAnnotation(coordinate: coordinate)
                riderAnnotation = annotation
                mapView.addAnnotation(annotation)
            }
            annotation.headingDegrees = headingDegrees
            (mapView.view(for: annotation) as? RiderAnnotationView)?.update(
                headingDegrees: headingDegrees,
                mapHeadingDegrees: mapView.camera.heading
            )
        }

        private func hasActiveGesture(in mapView: MKMapView) -> Bool {
            for subview in mapView.subviews {
                for recognizer in subview.gestureRecognizers ?? []
                where recognizer.state == .began || recognizer.state == .changed {
                    return true
                }
            }
            return false
        }
    }

    private enum Constants {
        static let markerReuseID = "ride-navigation-marker"
        static let riderReuseID = "ride-navigation-rider"
        static let plannedLineWidth: CGFloat = 7
        static let completedLineWidth: CGFloat = 8
        static let recordedLineWidth: CGFloat = 6
        static let rejoinLineWidth: CGFloat = 4
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

private final class NavigationPolyline: MKPolyline {
    var role = NavigationMapPolylineRole.planned
}

private final class NavigationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let role: NavigationMapMarkerRole

    init(coordinate: CLLocationCoordinate2D, title: String, role: NavigationMapMarkerRole) {
        self.coordinate = coordinate
        self.title = title
        self.role = role
    }
}

private final class RiderAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var headingDegrees: Double?

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

private final class RiderAnnotationView: MKAnnotationView {
    override var annotation: MKAnnotation? {
        didSet { configure() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func update(headingDegrees: Double?, mapHeadingDegrees: Double) {
        let relativeHeading = (headingDegrees ?? mapHeadingDegrees) - mapHeadingDegrees
        transform = CGAffineTransform(
            rotationAngle: relativeHeading * .pi / Constants.halfCircleDegrees
        )
    }

    private func configure() {
        image = UIImage(
            systemName: "location.north.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Constants.symbolSize)
        )?.withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
        displayPriority = .required
        collisionMode = .circle
        centerOffset = CGPoint(x: .zero, y: -Constants.centerOffset)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = Constants.shadowOpacity
        layer.shadowRadius = Constants.shadowRadius
        layer.shadowOffset = Constants.shadowOffset
    }

    private enum Constants {
        static let symbolSize: CGFloat = 34
        static let centerOffset: CGFloat = 8
        static let shadowOpacity: Float = 0.28
        static let shadowRadius: CGFloat = 3
        static let shadowOffset = CGSize(width: .zero, height: 2)
        static let halfCircleDegrees = 180.0
    }
}
