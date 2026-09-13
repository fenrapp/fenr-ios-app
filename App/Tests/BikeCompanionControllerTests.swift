import BikeDomain
import Foundation
import Testing
import TestSupport
import VehicleSession

@MainActor
struct BikeCompanionControllerTests {
    @Test func ownsChargingMonitoringAndReleasesItOnStopAndRestart() async {
        let hub = TestEventHub<VehicleSessionSnapshot>(bufferingPolicy: .unbounded)
        let vehicle = CompanionVehicleSessionSpy(hub: hub)
        let companion = BikeCompanionSessionSpy()
        let controller = BikeCompanionController(
            vehicleSession: vehicle, companion: companion, mapper: .init(), now: Date.init, monitoringID: UUID()
        )
        controller.start()
        controller.start()
        #expect(companion.activations == 1)
        #expect(await hub.waitForSubscriber())
        let source = VehicleSessionSnapshot(
            telemetry: BikeTelemetry(
                vin: "FENRTEST000000001", batteryLevel: .known(percent: 88),
                statusFlags: .init(isCharging: true), lastUpdated: Date()
            ),
            profile: .init(vin: "FENRTEST000000001"), isCanonicalTelemetryAvailable: true
        )
        await hub.send(source)
        #expect(await waitUntil { companion.snapshots.last?.isCharging == true })
        #expect(await vehicle.isMonitoring())
        await controller.stop()
        #expect(!(await vehicle.isMonitoring()))
        #expect(companion.snapshots.last?.bikeConnected == false)
        controller.start()
        #expect(await hub.waitForSubscriber())
        await hub.send(source)
        #expect(await waitUntil { companion.snapshots.last?.isCharging == true })
        await controller.stop()
        #expect(!(await vehicle.isMonitoring()))
    }

    @Test func deinitReleasesTheChargingLease() async {
        let hub = TestEventHub<VehicleSessionSnapshot>(bufferingPolicy: .unbounded)
        let vehicle = CompanionVehicleSessionSpy(hub: hub)
        let companion = BikeCompanionSessionSpy()
        var controller: BikeCompanionController? = BikeCompanionController(
            vehicleSession: vehicle, companion: companion, mapper: .init(), now: Date.init, monitoringID: UUID()
        )
        weak var releasedController = controller
        controller?.start()
        #expect(await hub.waitForSubscriber())
        await hub.send(VehicleSessionSnapshot(
            telemetry: chargingTelemetry(percent: 88), profile: .init(vin: "FENRTEST000000001"),
            isCanonicalTelemetryAvailable: true
        ))
        #expect(await waitUntil { await vehicle.isMonitoring() })
        controller = nil
        #expect(await waitUntil {
            let monitoring = await vehicle.isMonitoring()
            return releasedController == nil && !monitoring
        })
    }

    @Test func restartWaitsForThePreviousLeaseToBeReleased() async {
        let hub = TestEventHub<VehicleSessionSnapshot>(bufferingPolicy: .unbounded)
        let vehicle = CompanionVehicleSessionSpy(hub: hub)
        let companion = BikeCompanionSessionSpy()
        let controller = BikeCompanionController(
            vehicleSession: vehicle, companion: companion, mapper: .init(), now: Date.init, monitoringID: UUID()
        )
        controller.start()
        #expect(await hub.waitForSubscriber())
        await vehicle.pauseRelease()
        let stopping = Task { await controller.stop() }
        let releasePending = await waitUntil { await vehicle.hasPendingRelease() }
        #expect(releasePending)
        controller.start()
        #expect(companion.activations == 1)
        await vehicle.resumeRelease()
        await stopping.value
        #expect(companion.activations == 2)
        #expect(await hub.waitForSubscriber())
        await controller.stop()
    }

}
