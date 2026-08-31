import MapKit
import RideNavigation
import SwiftUI

struct FocusNavigationMapView: View {
    let scene: NavigationMapScene
    let onIntent: (NavigationMapIntent) -> Void
    let onInteraction: () -> Void
    @State private var settledTranslation = CGSize.zero
    @State private var settledScale = 1.0
    @State private var lastConcreteCamera = NavigationMapCamera.automatic
    @State private var isDragging = false
    @State private var isMagnifying = false
    @GestureState private var dragTranslation = CGSize.zero
    @GestureState private var gestureScale = 1.0

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Constants.background
                Canvas { context, size in
                    let viewport = FocusNavigationViewport(
                        scene: scene,
                        camera: effectiveCamera,
                        size: size
                    )
                    drawPolylines(in: &context, viewport: viewport)
                    drawMarkers(in: &context, viewport: viewport)
                    drawRider(in: &context, viewport: viewport)
                }
                .scaleEffect(effectiveScale)
                .offset(effectiveTranslation)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onInteraction)
            .simultaneousGesture(
                DragGesture(minimumDistance: Constants.interactionMinimumDistance)
                    .updating($dragTranslation) { value, translation, _ in
                        translation = value.translation
                    }
                    .onChanged { _ in
                        guard !isDragging else { return }
                        isDragging = true
                        beginMapInteraction()
                    }
                    .onEnded { value in
                        settledTranslation.width += value.translation.width
                        settledTranslation.height += value.translation.height
                        isDragging = false
                        onInteraction()
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($gestureScale) { value, scale, _ in
                        scale = value.magnification
                    }
                    .onChanged { _ in
                        guard !isMagnifying else { return }
                        isMagnifying = true
                        beginMapInteraction()
                    }
                    .onEnded { value in
                        settledScale = clampedScale(settledScale * value.magnification)
                        isMagnifying = false
                        onInteraction()
                    }
            )
            .onAppear { lastConcreteCamera = scene.camera }
            .onChange(of: scene.camera) { oldCamera, newCamera in
                guard !newCamera.isUserControlled else { return }
                lastConcreteCamera = newCamera
                guard oldCamera.isUserControlled else { return }
                resetViewportInteraction()
            }
            .accessibilityElement()
            .accessibilityLabel("Focus navigation map")
        }
    }

    private var effectiveCamera: NavigationMapCamera {
        scene.camera.isUserControlled ? lastConcreteCamera : scene.camera
    }

    private var effectiveTranslation: CGSize {
        CGSize(
            width: settledTranslation.width + dragTranslation.width,
            height: settledTranslation.height + dragTranslation.height
        )
    }

    private var effectiveScale: Double {
        clampedScale(settledScale * gestureScale)
    }

    private func beginMapInteraction() {
        onInteraction()
        guard !scene.camera.isUserControlled else { return }
        lastConcreteCamera = scene.camera
        onIntent(.userMovedCamera)
    }

    private func resetViewportInteraction() {
        settledTranslation = .zero
        settledScale = 1
    }

    private func clampedScale(_ value: Double) -> Double {
        min(max(value, Constants.minimumUserScale), Constants.maximumUserScale)
    }

    private func drawPolylines(
        in context: inout GraphicsContext,
        viewport: FocusNavigationViewport
    ) {
        for polyline in scene.polylines where polyline.points.count > 1 {
            var path = Path()
            for (index, coordinate) in polyline.points.enumerated() {
                let point = viewport.point(for: coordinate)
                if index == .zero {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            context.stroke(
                path,
                with: .color(color(for: polyline.role)),
                style: StrokeStyle(
                    lineWidth: lineWidth(for: polyline.role),
                    lineCap: .round,
                    lineJoin: .round,
                    dash: polyline.role == .rejoinGuide ? Constants.rejoinDash : []
                )
            )
        }
    }

    private func drawMarkers(
        in context: inout GraphicsContext,
        viewport: FocusNavigationViewport
    ) {
        for marker in scene.markers {
            let point = viewport.point(for: marker.coordinate)
            let rect = CGRect(
                x: point.x - Constants.markerRadius,
                y: point.y - Constants.markerRadius,
                width: Constants.markerRadius * 2,
                height: Constants.markerRadius * 2
            )
            context.fill(Path(ellipseIn: rect), with: .color(markerColor(for: marker.role)))
        }
    }

    private func drawRider(
        in context: inout GraphicsContext,
        viewport: FocusNavigationViewport
    ) {
        guard let coordinate = scene.userCoordinate else { return }
        let center = viewport.point(for: coordinate)
        let rotation = viewport.riderRotationDegrees
        var arrow = Path()
        arrow.move(to: CGPoint(x: .zero, y: -Constants.riderLength))
        arrow.addLine(to: CGPoint(x: Constants.riderHalfWidth, y: Constants.riderLength * 0.7))
        arrow.addLine(to: CGPoint(x: .zero, y: Constants.riderLength * 0.35))
        arrow.addLine(to: CGPoint(x: -Constants.riderHalfWidth, y: Constants.riderLength * 0.7))
        arrow.closeSubpath()
        var transform = CGAffineTransform(translationX: center.x, y: center.y)
        transform = transform.rotated(by: rotation * .pi / Constants.halfCircleDegrees)
        context.fill(arrow.applying(transform), with: .color(Constants.rider))
        context.stroke(
            arrow.applying(transform),
            with: .color(Constants.riderOutline),
            lineWidth: Constants.riderOutlineWidth
        )
    }

    private func color(for role: NavigationMapPolylineRole) -> Color {
        switch role {
        case .planned: Constants.planned
        case .approach: Constants.approach
        case .completed: Constants.completed
        case .recorded: Constants.recorded
        case .rejoinGuide: Constants.rejoin
        }
    }

    private func lineWidth(for role: NavigationMapPolylineRole) -> CGFloat {
        switch role {
        case .completed: Constants.completedLineWidth
        case .planned, .approach: Constants.routeLineWidth
        case .recorded: Constants.recordedLineWidth
        case .rejoinGuide: Constants.rejoinLineWidth
        }
    }

    private func markerColor(for role: NavigationMapMarkerRole) -> Color {
        switch role {
        case .start: Constants.markerPrimary
        case .finish: Constants.markerPrimary
        case .waypoint: Constants.markerSecondary
        case .participant: Constants.markerSecondary
        }
    }

    private enum Constants {
        static let background = Color.black
        static let planned = Color.white
        static let approach = Color.white
        static let completed = Color(white: 0.35)
        static let recorded = Color(white: 0.7)
        static let rejoin = Color.white
        static let markerPrimary = Color.white
        static let markerSecondary = Color(white: 0.55)
        static let rider = Color.white
        static let riderOutline = Color(white: 0.35)
        static let routeLineWidth: CGFloat = 8
        static let completedLineWidth: CGFloat = 6
        static let recordedLineWidth: CGFloat = 7
        static let rejoinLineWidth: CGFloat = 4
        static let rejoinDash: [CGFloat] = [2, 10]
        static let markerRadius: CGFloat = 6
        static let riderLength: CGFloat = 18
        static let riderHalfWidth: CGFloat = 12
        static let riderOutlineWidth: CGFloat = 3
        static let interactionMinimumDistance: CGFloat = 8
        static let minimumUserScale = 0.65
        static let maximumUserScale = 3.0
        static let halfCircleDegrees = 180.0
    }
}

private struct FocusNavigationViewport {
    let scene: NavigationMapScene
    let size: CGSize
    let center: MKMapPoint
    let scale: Double
    let rotationDegrees: Double
    let anchor: CGPoint

    init(
        scene: NavigationMapScene,
        camera: NavigationMapCamera,
        size: CGSize
    ) {
        self.scene = scene
        self.size = size
        switch camera {
        case .follow(let coordinate, let heading):
            center = MKMapPoint(coordinate.clCoordinate)
            scale = max(Double(size.height) / Constants.followHeightMeters, Constants.minimumScale)
            rotationDegrees = heading ?? .zero
            anchor = CGPoint(x: size.width / 2, y: size.height * Constants.riderVerticalAnchor)
        case .overview(let coordinates):
            let result = Self.overviewViewport(
                coordinates: coordinates.isEmpty ? Self.visibleCoordinates(in: scene) : coordinates,
                size: size
            )
            center = result.center
            scale = result.scale
            rotationDegrees = .zero
            anchor = CGPoint(x: size.width / 2, y: size.height / 2)
        case .automatic, .userControlled:
            let result = Self.overviewViewport(coordinates: Self.visibleCoordinates(in: scene), size: size)
            center = result.center
            scale = result.scale
            rotationDegrees = .zero
            anchor = CGPoint(x: size.width / 2, y: size.height / 2)
        }
    }

    var riderRotationDegrees: Double {
        (scene.userHeadingDegrees ?? .zero) - rotationDegrees
    }

    func point(for coordinate: NavigationMapCoordinate) -> CGPoint {
        let mapPoint = MKMapPoint(coordinate.clCoordinate)
        let metersPerMapPoint = MKMetersPerMapPointAtLatitude(coordinate.latitudeDegrees)
        let eastMeters = (mapPoint.x - center.x) * metersPerMapPoint
        let southMeters = (mapPoint.y - center.y) * metersPerMapPoint
        let radians = rotationDegrees * .pi / Constants.halfCircleDegrees
        let rotatedX = eastMeters * cos(radians) + southMeters * sin(radians)
        let rotatedY = -eastMeters * sin(radians) + southMeters * cos(radians)
        return CGPoint(
            x: anchor.x + CGFloat(rotatedX * scale),
            y: anchor.y + CGFloat(rotatedY * scale)
        )
    }

    private static func visibleCoordinates(in scene: NavigationMapScene) -> [NavigationMapCoordinate] {
        scene.polylines.flatMap(\.points) + scene.markers.map(\.coordinate) + [scene.userCoordinate].compactMap { $0 }
    }

    private static func overviewViewport(
        coordinates: [NavigationMapCoordinate],
        size: CGSize
    ) -> (center: MKMapPoint, scale: Double) {
        guard let first = coordinates.first else {
            return (MKMapPoint(x: .zero, y: .zero), Constants.minimumScale)
        }
        let points = coordinates.map { MKMapPoint($0.clCoordinate) }
        let minimumX = points.map(\.x).min() ?? first.clCoordinate.mapPoint.x
        let maximumX = points.map(\.x).max() ?? minimumX
        let minimumY = points.map(\.y).min() ?? first.clCoordinate.mapPoint.y
        let maximumY = points.map(\.y).max() ?? minimumY
        let center = MKMapPoint(x: (minimumX + maximumX) / 2, y: (minimumY + maximumY) / 2)
        let metersPerMapPoint = MKMetersPerMapPointAtLatitude(first.latitudeDegrees)
        let widthMeters = max((maximumX - minimumX) * metersPerMapPoint, Constants.minimumSpanMeters)
        let heightMeters = max((maximumY - minimumY) * metersPerMapPoint, Constants.minimumSpanMeters)
        let availableWidth = Double(max(size.width - Constants.horizontalPadding, 1))
        let availableHeight = Double(max(size.height - Constants.verticalPadding, 1))
        return (center, min(availableWidth / widthMeters, availableHeight / heightMeters))
    }

    private enum Constants {
        static let followHeightMeters = 900.0
        static let minimumScale = 0.05
        static let riderVerticalAnchor: CGFloat = 0.68
        static let horizontalPadding: CGFloat = 240
        static let verticalPadding: CGFloat = 220
        static let minimumSpanMeters = 200.0
        static let halfCircleDegrees = 180.0
    }
}

private extension NavigationMapCamera {
    var isUserControlled: Bool {
        if case .userControlled = self { return true }
        return false
    }
}
