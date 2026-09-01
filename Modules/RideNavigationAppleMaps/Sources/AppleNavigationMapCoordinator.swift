import MapKit
import RideNavigation

final class AppleNavigationMapCoordinator: NSObject, MKMapViewDelegate {
    var onIntent: (NavigationMapIntent) -> Void
    var onInteraction: () -> Void
    var renderedSource: MapSourceDescriptor?
    var renderedPolylineSignatures: [String: NavigationPolylineRenderSignature] = [:]
    var renderedPolylineOverlays: [String: NavigationPolyline] = [:]
    var renderedMarkers: [NavigationMapMarker] = []
    var renderedDirectionalIndicators: [NavigationMapDirectionalIndicator] = []
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
            renderer.lineWidth = MapRenderConstants.plannedLineWidth
        case .trailActive:
            renderer.strokeColor = .systemCyan
            renderer.lineWidth = MapRenderConstants.activeLineWidth
        case .trailCompleted:
            renderer.strokeColor = .systemGray
            renderer.lineWidth = MapRenderConstants.trailCompletedLineWidth
        case .trailFuture:
            renderer.strokeColor = .systemBlue.withAlphaComponent(MapRenderConstants.trailFutureOpacity)
            renderer.lineWidth = MapRenderConstants.trailFutureLineWidth
        case .completed:
            renderer.strokeColor = .systemCyan
            renderer.lineWidth = MapRenderConstants.completedLineWidth
        case .recorded:
            renderer.strokeColor = .systemRed
            renderer.lineWidth = MapRenderConstants.recordedLineWidth
        case .approach:
            renderer.strokeColor = .systemTeal
            renderer.lineWidth = MapRenderConstants.plannedLineWidth
        case .rejoinGuide:
            renderer.strokeColor = .white
            renderer.lineWidth = MapRenderConstants.rejoinLineWidth
            renderer.lineDashPattern = MapRenderConstants.rejoinDash
        }
        return renderer
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let rider = annotation as? RiderAnnotation {
            return riderView(for: rider, on: mapView)
        }
        if let indicator = annotation as? DirectionalAnnotation {
            return directionalView(for: indicator, on: mapView)
        }
        guard let marker = annotation as? NavigationAnnotation else { return nil }
        let view = mapView.dequeueReusableAnnotationView(
            withIdentifier: MapRenderConstants.markerReuseID,
            for: marker
        ) as? MKMarkerAnnotationView
        view?.markerTintColor = markerColor(for: marker.role)
        view?.glyphImage = UIImage(systemName: markerSymbol(for: marker.role))
        view?.displayPriority = .required
        return view
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        guard hasActiveGesture(in: mapView) else { return }
        onInteraction()
        onIntent(.userMovedCamera)
    }

    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        if let riderAnnotation,
           let view = mapView.view(for: riderAnnotation) as? RiderAnnotationView {
            view.update(
                headingDegrees: riderAnnotation.headingDegrees,
                mapHeadingDegrees: mapView.camera.heading
            )
        }
        for annotation in mapView.annotations.compactMap({ $0 as? DirectionalAnnotation }) {
            (mapView.view(for: annotation) as? DirectionalAnnotationView)?.update(
                rotationDegrees: annotation.rotationDegrees,
                mapHeadingDegrees: mapView.camera.heading
            )
        }
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

    private func riderView(for rider: RiderAnnotation, on mapView: MKMapView) -> MKAnnotationView? {
        let view = mapView.dequeueReusableAnnotationView(
            withIdentifier: MapRenderConstants.riderReuseID,
            for: rider
        ) as? RiderAnnotationView
        view?.update(
            headingDegrees: rider.headingDegrees,
            mapHeadingDegrees: mapView.camera.heading
        )
        return view
    }

    private func directionalView(
        for indicator: DirectionalAnnotation,
        on mapView: MKMapView
    ) -> MKAnnotationView? {
        let view = mapView.dequeueReusableAnnotationView(
            withIdentifier: MapRenderConstants.directionalIndicatorReuseID,
            for: indicator
        ) as? DirectionalAnnotationView
        view?.update(
            rotationDegrees: indicator.rotationDegrees,
            mapHeadingDegrees: mapView.camera.heading
        )
        return view
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

    private func markerColor(for role: NavigationMapMarkerRole) -> UIColor {
        return switch role {
        case .start: .systemGreen
        case .finish: .systemRed
        case .waypoint: .systemOrange
        case .participant: .systemPurple
        }
    }

    private func markerSymbol(for role: NavigationMapMarkerRole) -> String {
        return switch role {
        case .start: "location.north.fill"
        case .finish: "flag.checkered"
        case .waypoint: "mappin"
        case .participant: "person.fill"
        }
    }
}

struct NavigationPolylineRenderSignature: Equatable {
    let role: NavigationMapPolylineRole
    let revision: Int
}

enum MapRenderConstants {
    static let markerReuseID = "ride-navigation-marker"
    static let riderReuseID = "ride-navigation-rider"
    static let directionalIndicatorReuseID = "ride-navigation-directional-indicator"
    static let plannedLineWidth: CGFloat = 7
    static let activeLineWidth: CGFloat = 10
    static let trailCompletedLineWidth: CGFloat = 6
    static let trailFutureLineWidth: CGFloat = 5
    static let trailFutureOpacity: CGFloat = 0.7
    static let completedLineWidth: CGFloat = 8
    static let recordedLineWidth: CGFloat = 6
    static let rejoinLineWidth: CGFloat = 4
    static let rejoinDash: [NSNumber] = [2, 8]
}
