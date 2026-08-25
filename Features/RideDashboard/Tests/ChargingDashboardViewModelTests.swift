import BikeDomain
import ChargeControl
import Foundation
@testable import RideDashboard
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("Charging dashboard view model")
struct ChargingDashboardViewModelTests {
    @Test("Monitors charger data only for the charging state")
    func monitorsOnlyWhileCharging() async {
        let repository = ChargingDashboardRepository()
        let chargeControl = makeChargeControl(repository: repository)
        let locale = Locale(identifier: "en_US")
        let makeMapper: @Sendable (AppSettings) -> ChargingDashboardMapper = { settings in
            RideDashboardMapperFactory.makeChargingMapper(settings: settings, locale: locale)
        }
        let viewModel = ChargingDashboardViewModel(
            useCases: makeUseCases(repository: repository),
            chargeControl: chargeControl,
            mapper: makeMapper(AppSettings()),
            makeMapper: makeMapper
        )

        viewModel.start()
        await repository.sendTelemetry(BikeTelemetry())
        await Task.yield()
        #expect(await repository.monitoringStartCount() == 0)

        await repository.sendTelemetry(BikeTelemetry(statusFlags: .init(isCharging: true)))
        #expect(await waitUntil { await repository.monitoringStartCount() == 1 })
        #expect(await repository.monitoringStartCount() == 1)
        await repository.sendBatteryHealth(chargingHealth())
        #expect(await waitUntil { chargeControl.state.isEnabled })

        await repository.sendTelemetry(BikeTelemetry())
        #expect(await waitUntil { await repository.monitoringStopCount() == 1 })
        #expect(await repository.monitoringStopCount() == 1)
        #expect(!chargeControl.state.isVisible)
        viewModel.stop()
    }

    @Test("Waits for monitoring to stop before restarting it")
    func serializesMonitoringRestart() async {
        let repository = ChargingDashboardRepository()
        let viewModel = makeViewModel(repository: repository)
        await repository.suspendMonitoringStops()

        viewModel.start()
        await repository.sendTelemetry(BikeTelemetry(statusFlags: .init(isCharging: true)))
        #expect(await waitUntil { await repository.monitoringStartCount() == 1 })

        await repository.sendTelemetry(BikeTelemetry())
        #expect(await waitUntil { await repository.monitoringStopCount() == 1 })
        await repository.sendTelemetry(BikeTelemetry(statusFlags: .init(isCharging: true)))
        try? await Task.sleep(for: .milliseconds(30))
        #expect(await repository.monitoringStartCount() == 1)

        await repository.resumeMonitoringStops()
        #expect(await waitUntil { await repository.monitoringStartCount() == 2 })
        viewModel.stop()
    }

    private func makeViewModel(repository: ChargingDashboardRepository) -> ChargingDashboardViewModel {
        let locale = Locale(identifier: "en_US")
        let makeMapper: @Sendable (AppSettings) -> ChargingDashboardMapper = { settings in
            RideDashboardMapperFactory.makeChargingMapper(settings: settings, locale: locale)
        }
        return ChargingDashboardViewModel(
            useCases: makeUseCases(repository: repository),
            chargeControl: makeChargeControl(repository: repository),
            mapper: makeMapper(AppSettings()),
            makeMapper: makeMapper
        )
    }

    private func makeUseCases(repository: ChargingDashboardRepository) -> ChargingDashboardUseCases {
        .init(
            observeTelemetry: .init(repository: repository),
            observeBatteryHealth: .init(repository: repository),
            startBatteryHealthMonitoring: .init(repository: repository),
            stopBatteryHealthMonitoring: .init(repository: repository),
            observeSettings: .init(repository: ChargingDashboardSettingsRepository())
        )
    }

    private func makeChargeControl(repository: ChargingDashboardRepository) -> ChargeControlSession {
        ChargeControlSession(
            useCases: .init(
                prepare: .init(repository: repository),
                setPowerLimit: .init(repository: repository),
                setTarget: .init(repository: repository)
            ),
            logger: ChargeControlLogStore(),
            stateUpdater: ChargeControlStateUpdater(normalizer: ChargeControlNormalizer()),
            taskScheduler: ChargeControlTaskScheduler()
        )
    }

    private func chargingHealth() -> BikeBatteryHealth {
        .init(
            chargeState: .charging,
            chargingStatus: .init(
                requestedCurrentAmperes: 2.5,
                reportedCurrentAmperes: 2.5,
                maximumCurrentAmperes: 20,
                maximumPowerWatts: 1_000,
                targetCellVoltageVolts: 4.275,
                maximumStateOfChargePercent: 100,
                chargerType: .backpack
            )
        )
    }

}
