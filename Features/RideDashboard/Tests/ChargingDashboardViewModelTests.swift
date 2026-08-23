import BikeDomain
@testable import RideDashboard
import Testing
import TestSupport

@MainActor
@Suite("Charging dashboard view model")
struct ChargingDashboardViewModelTests {
    @Test("Monitors charger data only for the charging state")
    func monitorsOnlyWhileCharging() async {
        let repository = ChargingDashboardRepository()
        let viewModel = ChargingDashboardViewModel(useCases: makeUseCases(repository: repository))

        viewModel.start()
        await repository.sendTelemetry(BikeTelemetry())
        await Task.yield()
        #expect(await repository.monitoringStartCount() == 0)

        await repository.sendTelemetry(BikeTelemetry(statusFlags: .init(isCharging: true)))
        #expect(await waitUntil { await repository.monitoringStartCount() == 1 })
        #expect(await repository.monitoringStartCount() == 1)

        await repository.sendTelemetry(BikeTelemetry())
        #expect(await waitUntil { await repository.monitoringStopCount() == 1 })
        #expect(await repository.monitoringStopCount() == 1)
        viewModel.stop()
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

}
