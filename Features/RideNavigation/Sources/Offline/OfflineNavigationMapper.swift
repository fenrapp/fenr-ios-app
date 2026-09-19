import Foundation
import OfflineMapsDomain
import RideNavigationDomain

public struct OfflineNavigationMapper {
    private let geometry: OfflineGeometryService

    public init(geometry: OfflineGeometryService) { self.geometry = geometry }

    public func routeGeometry(_ route: RideRoute) -> OfflineGeometry {
        geometry.corridor(segments: route.segments.map { segment in
            segment.points.map { OfflineCoordinate(
                latitude: $0.coordinate.latitudeDegrees, longitude: $0.coordinate.longitudeDegrees
            )
            }
        }, marginMeters: 2_000)
    }

    public func routeStatus(_ requested: OfflineGeometry, snapshot: OfflineMapsSnapshot) -> String {
        let available = snapshot.regions.filter {
            $0.maximumZoom >= 16 && $0.layers.contains { $0.layer == .topographic && $0.available }
        }.map(\.geometry)
        switch geometry.availability(of: requested, within: available) {
        case .complete: return String(localized: .offlineRouteAvailable)
        case .partial: return String(localized: .offlineRoutePartial)
        case .unavailable: return String(localized: .offlineRoutePending)
        }
    }

    public func presentation(
        source: MapSourceDescriptor, coordinate: NavigationMapCoordinate?, snapshot: OfflineMapsSnapshot
    ) -> (source: MapSourceDescriptor, notice: String?) {
        guard snapshot.isReconciled else { return (source, String(localized: .offlineCheckingMaps)) }
        guard let coordinate else { return (source, String(localized: .offlineModeLocationPending)) }
        let point = OfflineCoordinate(latitude: coordinate.latitudeDegrees, longitude: coordinate.longitudeDegrees)
        let regions = snapshot.regions.filter { geometry.contains(point, in: $0.geometry) && $0.maximumZoom >= 16 }
        let topographic = regions.contains { $0.layers.contains { $0.layer == .topographic && $0.available } }
        let satellite = regions.contains { $0.layers.contains { $0.layer == .satellite && $0.available } }
        if source.id == MapSourceDescriptor.appleHybrid.id, !satellite, topographic {
            return (.appleStandard, String(localized: .offlineSatelliteFallback))
        }
        let ready = source.id == MapSourceDescriptor.appleHybrid.id ? satellite : topographic
        return (source, String(localized: ready ? .offlineMapIndicator : .offlineCoverageMissing))
    }
}

@MainActor
public struct OfflineNavigationDependencies {
    public let useCases: OfflineMapsUseCases
    public let mapper: OfflineNavigationMapper

    public init(useCases: OfflineMapsUseCases, mapper: OfflineNavigationMapper) {
        self.useCases = useCases
        self.mapper = mapper
    }
}
