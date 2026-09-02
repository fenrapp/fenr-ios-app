import MapKit
import RideNavigation
import SwiftUI

struct FocusNavigationViewport {
    let scene: NavigationMapScene
    let size: CGSize
    let center: MKMapPoint
    let scale: Double
    let rotationDegrees: Double
    let anchor: CGPoint

    init(scene: NavigationMapScene, camera: NavigationMapCamera, size: CGSize) {
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

    var mapTransform: CGAffineTransform {
        let radians = rotationDegrees * .pi / Constants.halfCircleDegrees
        let cosine = cos(radians)
        let sine = sin(radians)
        let matrixA = CGFloat(mapPointScale * cosine)
        let matrixB = CGFloat(-mapPointScale * sine)
        let matrixC = CGFloat(mapPointScale * sine)
        let matrixD = CGFloat(mapPointScale * cosine)
        return CGAffineTransform(
            a: matrixA,
            b: matrixB,
            c: matrixC,
            d: matrixD,
            tx: anchor.x - matrixA * CGFloat(center.x) - matrixC * CGFloat(center.y),
            ty: anchor.y - matrixB * CGFloat(center.x) - matrixD * CGFloat(center.y)
        )
    }

    var mapPointScale: Double {
        MKMetersPerMapPointAtLatitude(center.coordinate.latitude) * scale
    }

    func point(for coordinate: NavigationMapCoordinate) -> CGPoint {
        let mapPoint = MKMapPoint(coordinate.clCoordinate)
        return CGPoint(x: mapPoint.x, y: mapPoint.y).applying(mapTransform)
    }

    private static func visibleCoordinates(in scene: NavigationMapScene) -> [NavigationMapCoordinate] {
        scene.polylines.flatMap(\.points)
            + scene.markers.map(\.coordinate)
            + scene.directionalIndicators.map(\.coordinate)
            + [scene.userCoordinate].compactMap { $0 }
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
