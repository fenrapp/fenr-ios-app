import RideNavigation
import SwiftUI

extension FocusNavigationMapView {
    func drawMarkers(
        in context: inout GraphicsContext,
        viewport: FocusNavigationViewport
    ) {
        for marker in scene.markers {
            let point = viewport.point(for: marker.coordinate)
            var image = context.resolve(Image(systemName: markerSymbol(for: marker.role)))
            image.shading = .color(markerColor(for: marker.role))
            context.draw(image, at: point, anchor: .center)
        }
    }

    func drawDirectionalIndicators(
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

    private func markerColor(for role: NavigationMapMarkerRole) -> Color {
        return switch role {
        case .start: Constants.markerStart
        case .finish: Constants.markerFinish
        case .waypoint, .participant: Constants.markerSecondary
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

    private enum Constants {
        static let markerStart = Color.green
        static let markerFinish = Color.red
        static let markerSecondary = Color(white: 0.55)
        static let directionalIndicator = Color.white
        static let chevronHalfWidth: CGFloat = 7
        static let chevronHalfHeight: CGFloat = 5
        static let chevronLineWidth: CGFloat = 4
        static let halfCircleDegrees = 180.0
    }
}
