import Foundation

struct OfflineMapsRequest: Identifiable {
    let id = UUID()
    let routeID: UUID?
    let seed: OfflineMapSelectionSeed?

    init(routeID: UUID? = nil, seed: OfflineMapSelectionSeed? = nil) {
        self.routeID = routeID
        self.seed = seed
    }
}
