import Foundation
@testable import RideDashboard
import RideSessionDomain
import Testing
import TestSupport

@MainActor
@Suite("Ride dashboard feature lifecycle")
struct RideDashboardFeatureModelTests {
    @Test("Rearms global card observers only when presentation is live")
    func rearmsGlobalCardsAcrossContinuityPhases() async {
        let fixture = RideDashboardFeatureTestFixture.make()
        let dashboardFixture = fixture.dashboard
        let range = fixture.range
        let bikeLock = fixture.bikeLock
        let feature = fixture.feature
        var selection = DashboardCardSelectionState()

        feature.setPresentationActive(true)
        feature.synchronizeCardLifecycles(centerMode: .riding, selection: selection)
        #expect(!range.isObservingForTesting)
        #expect(!bikeLock.isObservingForTesting)
        #expect(await waitUntil {
            await dashboardFixture.vehicleSession.recordedObservationCount() == 1
        })

        await dashboardFixture.vehicleSession.send(ridingSnapshot(speed: 30))
        #expect(await waitUntil { dashboardFixture.viewModel.viewState.continuityPhase == .live })
        #expect(await waitUntil { range.isObservingForTesting })
        #expect(await waitUntil { bikeLock.isObservingForTesting })

        await dashboardFixture.vehicleSession.send(ridingSnapshot(
            speed: 90,
            isCanonicalTelemetryAvailable: false
        ))
        #expect(await waitUntil { dashboardFixture.viewModel.viewState.continuityPhase == .recovering })
        #expect(await waitUntil { !range.isObservingForTesting })
        #expect(bikeLock.isObservingForTesting)

        await verifySystemHealthSelectionDuringRecovery(
            feature: feature,
            vehicleSession: dashboardFixture.vehicleSession,
            selection: &selection
        )

        await dashboardFixture.vehicleSession.send(ridingSnapshot(speed: 31))
        #expect(await waitUntil { dashboardFixture.viewModel.viewState.continuityPhase == .live })
        #expect(await waitUntil { range.isObservingForTesting })
        #expect(bikeLock.isObservingForTesting)

        feature.setPresentationActive(false)
        #expect(!range.isObservingForTesting)
        #expect(!bikeLock.isObservingForTesting)
    }

    private func verifySystemHealthSelectionDuringRecovery(
        feature: RideDashboardFeatureModel,
        vehicleSession: RideDashboardVehicleSession,
        selection: inout DashboardCardSelectionState
    ) async {
        selection.ridingCard = .systemHealth
        feature.synchronizeCardLifecycles(centerMode: .riding, selection: selection)
        #expect(await waitUntil {
            await vehicleSession.recordedBatteryHealthMonitoringRequests() == [true]
        })

        selection.ridingCard = .speedometer
        feature.synchronizeCardLifecycles(centerMode: .riding, selection: selection)
        #expect(await waitUntil {
            await vehicleSession.recordedBatteryHealthMonitoringRequests() == [true, false]
        })

        selection.ridingCard = .systemHealth
        feature.synchronizeCardLifecycles(centerMode: .riding, selection: selection)
        #expect(await waitUntil {
            await vehicleSession.recordedBatteryHealthMonitoringRequests() == [true, false, true]
        })
    }
}
