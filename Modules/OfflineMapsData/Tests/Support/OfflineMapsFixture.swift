import Foundation
import OfflineMapsData
import OfflineMapsDomain
import TestSupport

@MainActor
struct OfflineMapsFixture {
    let backend: OfflineBackendStub
    let storage: OfflineStorageStub
    let network: OfflineNetworkStub
    let controller: OfflineMapsController

    init() {
        let backend = OfflineBackendStub()
        let storage = OfflineStorageStub()
        let network = OfflineNetworkStub()
        self.backend = backend
        self.storage = storage
        self.network = network
        controller = OfflineMapsController(backend: backend, storage: storage, network: network, now: Date.init)
    }

    func start() async -> Bool {
        controller.setActive(true)
        network.send()
        return await waitUntil { controller.snapshot.isReconciled && controller.snapshot.isConnected }
    }

    func enqueue(satellite: Bool = false) throws {
        try controller.enqueue(OfflineMapRequest(
            name: "Test area", geometry: OfflineGeometryService().rectangle(west: 1, south: 40, east: 2, north: 41),
            routeID: nil, satellite: satellite
        ), estimate: OfflineMapEstimate(transferBytes: 100, storageBytes: 100))
    }
}
