@testable import BikeSDK
import Testing

@Suite("Bike SDK IMU monitoring")
struct BikeSDKIMUMonitoringTests {
    @MainActor
    @Test("Monitoring lease is reference counted and reset with the session")
    func monitoringLease() {
        let store = BLESessionStore()

        #expect(store.acquireIMUMonitoringLease())
        #expect(!store.acquireIMUMonitoringLease())
        #expect(store.isIMUMonitoringActive())
        #expect(!store.releaseIMUMonitoringLease())
        #expect(store.releaseIMUMonitoringLease())
        #expect(!store.isIMUMonitoringActive())

        _ = store.acquireIMUMonitoringLease()
        store.resetSession()
        #expect(!store.isIMUMonitoringActive())
    }
}
