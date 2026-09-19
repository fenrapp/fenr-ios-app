import Foundation
import OfflineMapsDomain

@MainActor
extension RideNavigationViewModel {
    public var offlineSelectionSeed: OfflineMapSelectionSeed? {
        guard let route = planningController.snapshot.selectedRoute else { return nil }
        return OfflineMapSelectionSeed(
            name: route.name, routeID: route.id,
            segments: route.segments.map { segment in
                segment.points.map { dependencies.mapPresentationMapper.coordinate($0.coordinate) }
            },
            center: locationSnapshot.coordinate.map(dependencies.mapPresentationMapper.coordinate)
        )
    }
    func startOfflineObservation() {
        guard let offline = dependencies.offlineNavigation, offlineObserver == nil else { return }
        offlineObserver = offline.useCases.observe { [weak self] _ in self?.render() }
    }

    func stopOfflineObservation() {
        offlineRoutesTask?.cancel()
        offlineRoutesTask = nil
        offlineRoutesRevision = nil
        if let offlineObserver { dependencies.offlineNavigation?.useCases.removeObserver(offlineObserver) }
        offlineObserver = nil
    }

    func refreshOfflineRouteGeometry() {
        guard let offline = dependencies.offlineNavigation,
              offlineRoutesRevision != library.snapshot.revision else { return }
        offlineRoutesRevision = library.snapshot.revision
        let revision = offlineRoutesRevision
        let routes = library.snapshot.savedRoutes
        let routeLibrary = library.routeLibrary
        offlineRoutesTask?.cancel()
        offlineRoutesTask = Task { [weak self] in
            var geometries: [UUID: OfflineGeometry] = [:]
            for summary in routes {
                guard !Task.isCancelled else { return }
                if let route = try? await routeLibrary.loadRoute(id: summary.id) {
                    geometries[summary.id] = offline.mapper.routeGeometry(route)
                }
            }
            guard !Task.isCancelled, let self, offlineRoutesRevision == revision else { return }
            offlineRouteGeometry = geometries
            render()
        }
    }

    func offlineRows(_ rows: [RideNavigationRouteRow]) -> [RideNavigationRouteRow] {
        guard let offline = dependencies.offlineNavigation else { return rows }
        refreshOfflineRouteGeometry()
        return rows.map { row in
            RideNavigationRouteRow(
                id: row.id, title: row.title, detail: row.detail,
                offlineStatus: offlineRouteGeometry[row.id].map {
                    offline.mapper.routeStatus($0, snapshot: offline.useCases.snapshot)
                }
            )
        }
    }

}
