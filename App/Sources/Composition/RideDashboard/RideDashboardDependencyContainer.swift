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
    func makeFeature(
        dependencies: RideDashboardFeatureDependencies
    ) -> RideDashboardFeatureModel {
        let cards = makeCards(dependencies: dependencies)
        let lifecycle = RideDashboardCardLifecycleController(dependencies: cards)
        return RideDashboardFeatureModel(
            dashboardViewModel: makeViewModel(
                vehicleSession: dependencies.vehicleSession,
                onContinuityChanged: lifecycle.receiveContinuity
            ),
            deviceBatteryViewModel: DashboardDeviceBatteryViewModel(
                monitor: UIKitDashboardDeviceBatteryMonitor(
                    device: .current,
                    notificationCenter: .default
                ),
                observeSettings: ObserveAppSettingsUseCase(repository: dependencies.settingsRepository),
                updateSettings: UpdateAppSettingsUseCase(repository: dependencies.settingsRepository),
                mapper: DashboardDeviceBatteryMapper()
            ),
            currentTripViewModel: cards.currentTrip,
            tripStatisticsViewModel: cards.statistics,
            efficiencyViewModel: cards.efficiency,
            rangeViewModel: cards.range,
            systemHealthViewModel: cards.systemHealth,
            dynamicsViewModel: cards.dynamics,
            chargingViewModel: cards.charging,
            bikeLockViewModel: cards.bikeLock,
            cardLifecycle: lifecycle
        )
    }

    private func makeCards(
        dependencies: RideDashboardFeatureDependencies
    ) -> RideDashboardCardLifecycleDependencies {
        let tripViewModels = CurrentTripCardDependencyContainer.makeViewModels(
            dependencies: .init(
                rideTripRepository: dependencies.rideTripRepository,
                rideSession: dependencies.rideSession
            )
        )
        return RideDashboardCardLifecycleDependencies(
            currentTrip: tripViewModels.currentTrip,
            statistics: tripViewModels.statistics,
            efficiency: tripViewModels.efficiency,
            range: tripViewModels.range,
            systemHealth: SystemHealthCardViewModel(
                vehicleSession: dependencies.vehicleSession,
                mapper: RideDashboardMapperFactory.makeSystemHealthMapper(locale: .autoupdatingCurrent)
            ),
            dynamics: RideDynamicsCardViewModel(
                rideSession: dependencies.rideSession,
                vehicleSession: dependencies.vehicleSession,
                mapper: RideDashboardMapperFactory.makeRideDynamicsMapper(locale: .autoupdatingCurrent)
            ),
            charging: ChargingDashboardDependencyContainer.makeViewModel(
                vehicleSession: dependencies.vehicleSession,
                chargeControl: dependencies.chargeControl
            ),
            bikeLock: BikeLockCardViewModel(
                operationService: BikeLockCardOperationService(
                    readFirmwareCompatibility: ReadBikeLockFirmwareCompatibilityUseCase(
                        repository: dependencies.bikeRepository
                    ),
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
                securityOptionProvider: BikeLockSecurityOptionProvider()
            )
        )
    }

    private func makeViewModel(
        vehicleSession: any VehicleSessionService,
        onContinuityChanged: @escaping @MainActor (RideDashboardContinuityPhase) -> Void
    ) -> RideDashboardViewModel {
        RideDashboardViewModel(
            mapper: RideDashboardMapperFactory.makeRideMapper(locale: .autoupdatingCurrent),
            cardLayoutMapper: DashboardCardLayoutMapper(),
            vehicleSession: vehicleSession,
            timing: .live,
            continuityPolicy: RideDashboardContinuityPolicy(),
            initialConnectionStabilityPeriod:
                FENRRuntimeConstants.Telemetry.connectionStabilityPeriod,
            reconnectionNoticeDelay: FENRRuntimeConstants.RideDashboard.reconnectionNoticeDelay,
            onContinuityChanged: onContinuityChanged
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
}
