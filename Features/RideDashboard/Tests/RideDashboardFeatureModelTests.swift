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
        let dashboardFixture = makeFixture()
        let rangeSession = TestRideSessionService()
        let range = RangeCardViewModel(
            useCases: .init(
                loadHistory: .init(repository: CurrentTripCardTripRepository())
            ),
            mapper: .init(
                locale: Locale(identifier: "en_GB"),
                estimator: RideRangeEstimator()
            ),
            session: rangeSession
        )
        let bikeLock = BikeLockCardViewModelTestFactory.make().viewModel
        let systemHealth = SystemHealthCardViewModel(
            vehicleSession: dashboardFixture.vehicleSession,
            mapper: RideDashboardMapperFactory.makeSystemHealthMapper(locale: Locale(identifier: "en_GB"))
        )
        let feature = RideDashboardFeatureModel(
            dashboardViewModel: dashboardFixture.viewModel,
            deviceBatteryViewModel: DashboardDeviceBatteryPreviewFactory.makeViewModel(),
            currentTripViewModel: CurrentTripCardPreviewFactory.makeViewModel(state: .init()),
            tripStatisticsViewModel: TripStatisticsCardPreviewFactory.makeViewModel(state: .init()),
            efficiencyViewModel: EfficiencyCardPreviewFactory.makeViewModel(state: .init()),
            rangeViewModel: range,
            systemHealthViewModel: systemHealth,
            dynamicsViewModel: RideDynamicsCardPreviewFactory.makeViewModel(state: .init()),
            chargingViewModel: ChargingDashboardPreviewFactory.makeViewModel(state: .init()),
            bikeLockViewModel: bikeLock
        )
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
