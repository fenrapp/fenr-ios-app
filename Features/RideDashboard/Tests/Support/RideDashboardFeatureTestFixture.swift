import Foundation
@testable import RideDashboard
import RideSessionDomain

@MainActor
struct RideDashboardFeatureTestFixture {
    let dashboard: RideDashboardViewModelTestFixture
    let feature: RideDashboardFeatureModel
    let range: RangeCardViewModel
    let bikeLock: BikeLockCardViewModel
    let cardLifecycle: RideDashboardCardLifecycleController

    static func make() -> Self {
        let vehicleSession = RideDashboardVehicleSession()
        let range = RangeCardViewModel(
            useCases: .init(loadHistory: .init(repository: CurrentTripCardTripRepository())),
            mapper: .init(locale: Locale(identifier: "en_GB"), estimator: RideRangeEstimator()),
            session: TestRideSessionService()
        )
        let bikeLock = BikeLockCardViewModelTestFactory.make().viewModel
        let systemHealth = SystemHealthCardViewModel(
            vehicleSession: vehicleSession,
            mapper: RideDashboardMapperFactory.makeSystemHealthMapper(locale: Locale(identifier: "en_GB"))
        )
        let currentTrip = CurrentTripCardPreviewFactory.makeViewModel(state: .init())
        let statistics = TripStatisticsCardPreviewFactory.makeViewModel(state: .init())
        let efficiency = EfficiencyCardPreviewFactory.makeViewModel(state: .init())
        let dynamics = RideDynamicsCardPreviewFactory.makeViewModel(state: .init())
        let charging = ChargingDashboardPreviewFactory.makeViewModel(state: .init())
        let cardLifecycle = RideDashboardCardLifecycleController(dependencies: .init(
            currentTrip: currentTrip, statistics: statistics, efficiency: efficiency,
            range: range, systemHealth: systemHealth, dynamics: dynamics, charging: charging, bikeLock: bikeLock
        ))
        let dashboard = makeFixture(
            vehicleSession: vehicleSession, onContinuityChanged: cardLifecycle.receiveContinuity
        )
        let feature = RideDashboardFeatureModel(
            dashboardViewModel: dashboard.viewModel,
            deviceBatteryViewModel: DashboardDeviceBatteryPreviewFactory.makeViewModel(),
            currentTripViewModel: currentTrip, tripStatisticsViewModel: statistics,
            efficiencyViewModel: efficiency, rangeViewModel: range, systemHealthViewModel: systemHealth,
            dynamicsViewModel: dynamics, chargingViewModel: charging, bikeLockViewModel: bikeLock,
            cardLifecycle: cardLifecycle
        )
        return Self(
            dashboard: dashboard, feature: feature, range: range, bikeLock: bikeLock, cardLifecycle: cardLifecycle
        )
    }
}
