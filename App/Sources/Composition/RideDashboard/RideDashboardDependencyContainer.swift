import BikeDomain
import ChargeControl
import Foundation
import RideDashboard
import RideSession
import RideSessionDomain
import RuntimeConfiguration
import SettingsDomain
import UIKit
import VehicleSession

@MainActor
struct RideDashboardDependencyContainer {
    private let currentTripContainer = CurrentTripCardDependencyContainer()
    private let chargingContainer = ChargingDashboardDependencyContainer()

    func makeFeature(
        dependencies: RideDashboardFeatureDependencies
    ) -> RideDashboardFeatureModel {
        let tripViewModels = currentTripContainer.makeViewModels(
            dependencies: .init(
                rideTripRepository: dependencies.rideTripRepository,
                rideSession: dependencies.rideSession
            )
        )
        return RideDashboardFeatureModel(
            dashboardViewModel: makeViewModel(
                vehicleSession: dependencies.vehicleSession
            ),
            deviceBatteryViewModel: DashboardDeviceBatteryViewModel(
                monitor: UIKitDashboardDeviceBatteryMonitor(
                    device: .current,
                    notificationCenter: .default
                )
            ),
            currentTripViewModel: tripViewModels.currentTrip,
            tripStatisticsViewModel: tripViewModels.statistics,
            efficiencyViewModel: tripViewModels.efficiency,
            rangeViewModel: tripViewModels.range,
            systemHealthViewModel: SystemHealthCardViewModel(
                vehicleSession: dependencies.vehicleSession,
                mapper: RideDashboardMapperFactory.makeSystemHealthMapper(locale: .autoupdatingCurrent)
            ),
            dynamicsViewModel: RideDynamicsCardViewModel(
                rideSession: dependencies.rideSession,
                vehicleSession: dependencies.vehicleSession,
                mapper: RideDashboardMapperFactory.makeRideDynamicsMapper(locale: .autoupdatingCurrent)
            ),
            chargingViewModel: chargingContainer.makeViewModel(
                vehicleSession: dependencies.vehicleSession,
                chargeControl: dependencies.chargeControl
            )
        )
    }

    private func makeViewModel(
        vehicleSession: any VehicleSessionService
    ) -> RideDashboardViewModel {
        RideDashboardViewModel(
            mapper: RideDashboardMapperFactory.makeRideMapper(locale: .autoupdatingCurrent),
            cardLayoutMapper: DashboardCardLayoutMapper(),
            vehicleSession: vehicleSession,
            initialConnectionStabilityPeriod:
                FENRRuntimeConstants.Telemetry.connectionStabilityPeriod,
            reconnectionGracePeriod: FENRRuntimeConstants.RideDashboard.reconnectionGracePeriod
        )
    }
}

struct RideDashboardFeatureDependencies {
    let rideTripRepository: any RideTripRepository
    let chargeControl: ChargeControlSession
    let rideSession: any RideSessionService
    let vehicleSession: any VehicleSessionService
}
