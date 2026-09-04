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
        viewport: FocusNavigationViewport,
        palette: FocusNavigationPalette
    ) {
        drawPolylines(scene: scene, in: &context, viewport: viewport, palette: palette)
        drawDirectionalIndicators(scene: scene, in: &context, viewport: viewport, palette: palette)
        drawMarkers(scene: scene, in: &context, viewport: viewport, palette: palette)
        drawCompassRing(scene: scene, in: &context, viewport: viewport, palette: palette)
        drawRider(scene: scene, in: &context, viewport: viewport, palette: palette)
    }

    private func drawCompassRing(
        scene: NavigationMapScene,
        in context: inout GraphicsContext,
        viewport: FocusNavigationViewport,
        palette: FocusNavigationPalette
    ) {
        guard scene.showsCompassRing, let coordinate = scene.userCoordinate else { return }
        let center = viewport.point(for: coordinate)
        let diameter = Constants.compassRadius * 2
        let ringRect = CGRect(
            x: center.x - Constants.compassRadius,
            y: center.y - Constants.compassRadius,
            width: diameter,
            height: diameter
        )
        context.stroke(
            Path(ellipseIn: ringRect),
            with: .color(palette.compassRing),
            lineWidth: Constants.compassRingWidth
        )
        for cardinal in NavigationCardinal.allCases {
            let angle = (cardinal.bearingDegrees - viewport.rotationDegrees)
                * .pi / Constants.halfCircleDegrees
            var label = context.resolve(
                Text(cardinal.resource).font(
                    .system(
                        size: Constants.compassFontSize,
                        weight: cardinal.isNorth ? .bold : .medium
                    )
                )
            )
            let size = label.measure(in: Constants.compassLabelMeasurementSize)
            let radialHalfExtent = abs(sin(angle)) * size.width / 2
                + abs(cos(angle)) * size.height / 2
            let labelRadius = Constants.compassRadius
                + Constants.compassLabelMargin
                + radialHalfExtent
            let point = CGPoint(
                x: center.x + sin(angle) * labelRadius,
                y: center.y - cos(angle) * labelRadius
            )
            if cardinal.isNorth {
                label.shading = .linearGradient(
                    palette.compassNorthGradient,
                    startPoint: CGPoint(x: point.x, y: point.y - size.height / 2),
                    endPoint: CGPoint(x: point.x, y: point.y + size.height / 2)
                )
            } else {
                label.shading = .color(palette.compassSecondary)
            }
            context.draw(label, at: point, anchor: .center)
        }
    }

    private func drawPolylines(
        scene: NavigationMapScene,
        in context: inout GraphicsContext,
        viewport: FocusNavigationViewport,
        palette: FocusNavigationPalette
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
                    with: .color(palette.polylineColor(for: polyline.role)),
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
        viewport: FocusNavigationViewport,
        palette: FocusNavigationPalette
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
        context.fill(arrow.applying(transform), with: .color(palette.rider))
        context.stroke(
            arrow.applying(transform),
            with: .color(palette.riderOutline),
            lineWidth: Constants.riderOutlineWidth
        )
    }

    private func drawMarkers(
        scene: NavigationMapScene,
        in context: inout GraphicsContext,
        viewport: FocusNavigationViewport,
        palette: FocusNavigationPalette
    ) {
        for marker in scene.markers {
            var image = context.resolve(Image(systemName: markerSymbol(for: marker.role)))
            image.shading = .color(palette.markerColor(for: marker.role))
            context.draw(image, at: viewport.point(for: marker.coordinate), anchor: .center)
        }
    }

    private func drawDirectionalIndicators(
        scene: NavigationMapScene,
        in context: inout GraphicsContext,
        viewport: FocusNavigationViewport,
        palette: FocusNavigationPalette
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
                with: .color(palette.directionalIndicator),
                style: StrokeStyle(
                    lineWidth: Constants.chevronLineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
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
        static let riderLength: CGFloat = 18
        static let riderHalfWidth: CGFloat = 12
        static let riderOutlineWidth: CGFloat = 3
        static let chevronHalfWidth: CGFloat = 7
        static let chevronHalfHeight: CGFloat = 5
        static let chevronLineWidth: CGFloat = 4
        static let compassRadius: CGFloat = 38
        static let compassLabelMargin: CGFloat = 2
        static let compassLabelMeasurementSize = CGSize(width: 100, height: 100)
        static let compassRingWidth: CGFloat = 1.5
        static let compassFontSize: CGFloat = 9
        static let halfCircleDegrees = 180.0
    }
}
