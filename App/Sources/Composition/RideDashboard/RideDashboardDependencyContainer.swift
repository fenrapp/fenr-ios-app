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
                ),
                loadSettings: LoadAppSettingsUseCase(repository: dependencies.settingsRepository),
                saveSettings: SaveAppSettingsUseCase(repository: dependencies.settingsRepository),
                mapper: DashboardDeviceBatteryMapper()
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
            ),
            bikeLockViewModel: BikeLockCardViewModel(
                operationService: BikeLockCardOperationService(
                    prepareControl: PrepareBikeLockControlUseCase(repository: dependencies.bikeRepository),
                    setLocked: SetBikeLockedUseCase(repository: dependencies.bikeRepository),
                    updateSecurity: UpdateBikeLockSecurityUseCase(
                        repository: dependencies.settingsRepository,
                        credentialStore: dependencies.bikeLockCredentialStore
                    ),
                    credentialStore: dependencies.bikeLockCredentialStore,
                    authenticator: dependencies.bikeLockAuthenticator
                ),
                vehicleSession: dependencies.vehicleSession,
                capabilityStore: dependencies.bikeLockCapabilityStore,
                mapper: BikeLockCardViewStateMapper(),
                vehicleContextMapper: BikeLockCardVehicleContextMapper(),
                securityOptionProvider: BikeLockSecurityOptionProvider(),
                allowsExperimentalControl: dependencies.allowsExperimentalBikeLockControl
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
            timing: .live,
            continuityPolicy: RideDashboardContinuityPolicy(),
            initialConnectionStabilityPeriod:
                FENRRuntimeConstants.Telemetry.connectionStabilityPeriod,
            reconnectionNoticeDelay: FENRRuntimeConstants.RideDashboard.reconnectionNoticeDelay
        )
    }
}

struct RideDashboardFeatureDependencies {
    let bikeRepository: any BikeRepository
    let rideTripRepository: any RideTripRepository
    let chargeControl: ChargeControlSession
    let rideSession: any RideSessionService
    let settingsRepository: any AppSettingsRepository
    let vehicleSession: any VehicleSessionService
    let bikeLockCredentialStore: any BikeLockCredentialStoring
    let bikeLockAuthenticator: any BikeLockAuthenticating
    let bikeLockCapabilityStore: any BikeLockCapabilityStateStoring
    let allowsExperimentalBikeLockControl: Bool
}
