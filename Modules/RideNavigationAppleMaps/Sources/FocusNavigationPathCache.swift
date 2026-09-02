import MapKit
import RideNavigation
import SwiftUI

@MainActor
final class FocusNavigationPathCache {
    private struct Entry {
        let revision: Int
        let path: Path
    }

    private var entries: [String: Entry] = [:]

    func path(for polyline: NavigationMapPolyline) -> Path {
        if let entry = entries[polyline.id], entry.revision == polyline.revision {
            return entry.path
        }
        var path = Path()
        for (index, coordinate) in polyline.points.enumerated() {
            let mapPoint = MKMapPoint(coordinate.clCoordinate)
            let renderPoint = CGPoint(x: mapPoint.x, y: mapPoint.y)
            if index == .zero {
                path.move(to: renderPoint)
            } else {
                path.addLine(to: renderPoint)
            }
        }
        entries[polyline.id] = Entry(revision: polyline.revision, path: path)
        return path
    }
}
