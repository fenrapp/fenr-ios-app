import EnvironmentDomain
import Foundation
import OfflineMapsDomain
import RideNavigation
import RideNavigationDomain

enum OfflineViewModelFixtures {
    static let routeStart = NavigationMapCoordinate(latitudeDegrees: 41, longitudeDegrees: 2)!
    static let routeEnd = NavigationMapCoordinate(latitudeDegrees: 41.01, longitudeDegrees: 2.01)!
    static let distantLocation = NavigationMapCoordinate(latitudeDegrees: 48, longitudeDegrees: 10)!

    static var routeSeed: OfflineMapSelectionSeed {
        OfflineMapSelectionSeed(
            name: "Synthetic route", routeID: UUID(), segments: [[routeStart, routeEnd]], center: distantLocation
        )
    }

    static var importedRoute: RideRoute {
        RideRoute(
            name: "Synthetic imported route", createdAt: Date(timeIntervalSince1970: 0),
            segments: [routeStart, routeEnd].map { point in
                RideRouteSegment(points: [RideRoutePoint(coordinate: .init(
                    latitudeDegrees: point.latitudeDegrees, longitudeDegrees: point.longitudeDegrees
                )!)])
            }
        )
    }

    static var positionSample: DeviceSpeedSample {
        DeviceSpeedSample(
            kilometersPerHour: 0, accuracyMetersPerSecond: 1,
            coordinate: GeographicCoordinate(
                latitudeDegrees: distantLocation.latitudeDegrees, longitudeDegrees: distantLocation.longitudeDegrees
            ),
            observedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    static func region(status: OfflineDownloadStatus = .ready) -> OfflineRegion {
        var region = OfflineRegion(
            id: UUID(), name: "Synthetic", geometry: OfflineGeometryService().rectangle(
                west: 0, south: 0, east: 1, north: 1
            ),
            routeID: nil,
            layers: [OfflineLayerRecord(layer: .topographic, resourceID: "synthetic", available: true)],
            now: Date(timeIntervalSince1970: 0)
        )
        region.status = status
        return region
    }
}
