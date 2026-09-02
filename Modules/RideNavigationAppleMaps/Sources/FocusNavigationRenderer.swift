import RideNavigation
import SwiftUI

@MainActor
final class FocusNavigationRenderer {
    private let pathCache: FocusNavigationPathCache

    init(pathCache: FocusNavigationPathCache) {
        self.pathCache = pathCache
    }

    func draw(
        scene: NavigationMapScene,
        in context: inout GraphicsContext,
        viewport: FocusNavigationViewport
    ) {
        drawPolylines(scene: scene, in: &context, viewport: viewport)
        drawDirectionalIndicators(scene: scene, in: &context, viewport: viewport)
        drawMarkers(scene: scene, in: &context, viewport: viewport)
        drawRider(scene: scene, in: &context, viewport: viewport)
    }

    private func drawPolylines(
        scene: NavigationMapScene,
        in context: inout GraphicsContext,
        viewport: FocusNavigationViewport
    ) {
        let polylines = scene.polylines.sorted { $0.role.renderPriority < $1.role.renderPriority }
        for polyline in polylines where polyline.points.count > 1 {
            let path = pathCache.path(for: polyline)
            let scale = CGFloat(viewport.mapPointScale)
            let dash = polyline.role == .rejoinGuide ? Constants.rejoinDash.map { $0 / scale } : []
            context.drawLayer { layer in
                layer.concatenate(viewport.mapTransform)
                layer.stroke(
                    path,
                    with: .color(color(for: polyline.role)),
                    style: StrokeStyle(
                        lineWidth: lineWidth(for: polyline.role) / scale,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: dash
                    )
                )
            }
        }
    }

    private func drawRider(
        scene: NavigationMapScene,
        in context: inout GraphicsContext,
        viewport: FocusNavigationViewport
    ) {
        guard let coordinate = scene.userCoordinate else { return }
        let center = viewport.point(for: coordinate)
        var arrow = Path()
        arrow.move(to: CGPoint(x: .zero, y: -Constants.riderLength))
        arrow.addLine(to: CGPoint(x: Constants.riderHalfWidth, y: Constants.riderLength * 0.7))
        arrow.addLine(to: CGPoint(x: .zero, y: Constants.riderLength * 0.35))
        arrow.addLine(to: CGPoint(x: -Constants.riderHalfWidth, y: Constants.riderLength * 0.7))
        arrow.closeSubpath()
        var transform = CGAffineTransform(translationX: center.x, y: center.y)
        transform = transform.rotated(
            by: viewport.riderRotationDegrees * .pi / Constants.halfCircleDegrees
        )
        context.fill(arrow.applying(transform), with: .color(Constants.rider))
        context.stroke(
            arrow.applying(transform),
            with: .color(Constants.riderOutline),
            lineWidth: Constants.riderOutlineWidth
        )
    }

    private func drawMarkers(
        scene: NavigationMapScene,
        in context: inout GraphicsContext,
        viewport: FocusNavigationViewport
    ) {
        for marker in scene.markers {
            var image = context.resolve(Image(systemName: markerSymbol(for: marker.role)))
            image.shading = .color(markerColor(for: marker.role))
            context.draw(image, at: viewport.point(for: marker.coordinate), anchor: .center)
        }
    }

    private func drawDirectionalIndicators(
        scene: NavigationMapScene,
        in context: inout GraphicsContext,
        viewport: FocusNavigationViewport
    ) {
        for indicator in scene.directionalIndicators {
            let center = viewport.point(for: indicator.coordinate)
            var chevron = Path()
            chevron.move(to: CGPoint(x: -Constants.chevronHalfWidth, y: Constants.chevronHalfHeight))
            chevron.addLine(to: CGPoint(x: .zero, y: -Constants.chevronHalfHeight))
            chevron.addLine(to: CGPoint(x: Constants.chevronHalfWidth, y: Constants.chevronHalfHeight))
            var transform = CGAffineTransform(translationX: center.x, y: center.y)
            transform = transform.rotated(
                by: (indicator.rotationDegrees - viewport.rotationDegrees)
                    * .pi / Constants.halfCircleDegrees
            )
            context.stroke(
                chevron.applying(transform),
                with: .color(Constants.directionalIndicator),
                style: StrokeStyle(
                    lineWidth: Constants.chevronLineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    private func color(for role: NavigationMapPolylineRole) -> Color {
        switch role {
        case .planned, .trailActive, .approach, .rejoinGuide: .white
        case .trailFuture: Color(white: 0.72)
        case .trailCompleted, .completed: Color(white: 0.35)
        case .recorded: Color(white: 0.7)
        }
    }

    private func lineWidth(for role: NavigationMapPolylineRole) -> CGFloat {
        switch role {
        case .completed, .trailCompleted: Constants.completedLineWidth
        case .trailActive: Constants.activeLineWidth
        case .trailFuture: Constants.trailFutureLineWidth
        case .planned, .approach: Constants.routeLineWidth
        case .recorded: Constants.recordedLineWidth
        case .rejoinGuide: Constants.rejoinLineWidth
        }
    }

    private func markerColor(for role: NavigationMapMarkerRole) -> Color {
        switch role {
        case .start: .green
        case .finish: .red
        case .waypoint, .participant: Color(white: 0.55)
        }
    }

    private func markerSymbol(for role: NavigationMapMarkerRole) -> String {
        switch role {
        case .start: "location.north.fill"
        case .finish: "flag.checkered"
        case .waypoint: "mappin"
        case .participant: "person.fill"
        }
    }

    private enum Constants {
        static let routeLineWidth: CGFloat = 8
        static let activeLineWidth: CGFloat = 11
        static let trailFutureLineWidth: CGFloat = 5
        static let completedLineWidth: CGFloat = 6
        static let recordedLineWidth: CGFloat = 7
        static let rejoinLineWidth: CGFloat = 4
        static let rejoinDash: [CGFloat] = [2, 10]
        static let rider = Color.white
        static let riderOutline = Color(white: 0.35)
        static let riderLength: CGFloat = 18
        static let riderHalfWidth: CGFloat = 12
        static let riderOutlineWidth: CGFloat = 3
        static let directionalIndicator = Color.white
        static let chevronHalfWidth: CGFloat = 7
        static let chevronHalfHeight: CGFloat = 5
        static let chevronLineWidth: CGFloat = 4
        static let halfCircleDegrees = 180.0
    }
}
