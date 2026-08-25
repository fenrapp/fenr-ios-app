import BikeDomain
import Foundation
import SettingsDomain
import Testing
import TestSupport
@testable import WatchDashboard

@MainActor
struct WatchDashboardViewModelTests {
    @Test("charging monitoring is started only while charging")
    func chargingMonitoringFollowsRunState() async {
        let repository = WatchDashboardRepository()
        let viewModel = WatchDashboardViewModel(
            useCases: .init(
                repository: repository,
                batteryHealthRepository: repository,
                settingsRepository: WatchDashboardSettingsRepository()
            ),
            mapper: makeMapper(),
            maximumDebugEvents: 12
        )

        viewModel.start()
        await repository.send(.init(
            statusFlags: .init(isOn: true),
            lastUpdated: .now
        ))
        #expect(await waitUntil { await repository.startMonitoringCalls == 0 })

        await repository.send(.init(
            batteryLevel: .known(percent: 42),
            statusFlags: .init(isCharging: true),
            lastUpdated: .now
        ))
        #expect(await waitUntil { await repository.startMonitoringCalls == 1 })
        #expect(viewModel.viewState.mode == .charging)

        await repository.send(.init(
            statusFlags: .init(isOn: true),
            lastUpdated: .now
        ))
        #expect(await waitUntil { viewModel.viewState.mode == .ride })
        #expect(await waitUntil { await repository.stopMonitoringCalls == 1 })
    }

    @Test("charging state presents health data using selected units")
    func chargingStateUsesBatteryHealthAndSettings() async {
        let repository = WatchDashboardRepository()
        let settings = WatchDashboardSettingsRepository(
            settings: .init(measurementSystem: .metric)
        )
        let viewModel = WatchDashboardViewModel(
            useCases: .init(
                repository: repository,
                batteryHealthRepository: repository,
                settingsRepository: settings
            ),
            mapper: makeMapper(),
            maximumDebugEvents: 12
        )

        viewModel.start()
        await repository.send(.init(
            batteryLevel: .known(percent: 80),
            statusFlags: .init(isCharging: true),
            lastUpdated: .now
        ))
        #expect(await waitUntil { await repository.startMonitoringCalls == 1 })

        await repository.send(.init(
            dcBusVoltage: .known(volts: 400),
            temperatures: [.init(position: 1, celsius: 30)],
            chargingStatus: .init(
                requestedCurrentAmperes: 4,
                reportedCurrentAmperes: 4,
                maximumCurrentAmperes: 20,
                maximumPowerWatts: 2_000,
                targetCellVoltageVolts: 4.275,
                maximumStateOfChargePercent: 100
            )
        ))

        #expect(await waitUntil {
            viewModel.viewState.chargingPower == "2 kW"
        })
        #expect(viewModel.viewState.chargingCurrent == "4 A")
        #expect(viewModel.viewState.batteryTemperature == "30 °C")
        #expect(viewModel.viewState.chargeETA != nil)
    }

    @Test("monitoring restart waits for the previous stop")
    func monitoringRestartWaitsForStop() async throws {
        let repository = WatchDashboardRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.start()
        await repository.send(chargingTelemetry())
        #expect(await waitUntil { await repository.startMonitoringCalls == 1 })
        await repository.suspendMonitoringStop()

        await repository.send(.init(statusFlags: .init(isOn: true), lastUpdated: .now))
        #expect(await waitUntil { await repository.stopMonitoringCalls == 1 })
        await repository.send(chargingTelemetry())
        try await Task.sleep(for: .milliseconds(50))
        #expect(await repository.startMonitoringCalls == 1)

        await repository.resumeMonitoringStop()
        #expect(await waitUntil { await repository.startMonitoringCalls == 2 })
    }

    @Test("dashboard retains recent debug events")
    func retainsRecentDebugEvents() async {
        let repository = WatchDashboardRepository()
        let viewModel = WatchDashboardViewModel(
            useCases: .init(
                repository: repository,
                batteryHealthRepository: repository,
                settingsRepository: WatchDashboardSettingsRepository()
            ),
            mapper: makeMapper(),
            maximumDebugEvents: 12
        )

        viewModel.start()
        await repository.send(.init(title: "BLE", detail: "scan started"))

        #expect(await waitUntil { viewModel.debugEvents.first?.title == "BLE" })
        #expect(viewModel.debugEvents.first?.detail == "scan started")
    }

    private func makeMapper() -> WatchDashboardViewStateMapper {
        WatchDashboardMapperFactory.make(
            locale: Locale(identifier: "en_US"),
            now: Date.init,
            telemetryFreshnessInterval: 60
        )
    }

    private func makeViewModel(repository: WatchDashboardRepository) -> WatchDashboardViewModel {
        WatchDashboardViewModel(
            useCases: .init(
                repository: repository,
                batteryHealthRepository: repository,
                settingsRepository: WatchDashboardSettingsRepository()
            ),
            mapper: makeMapper(),
            maximumDebugEvents: 12
        )
    }

    private func chargingTelemetry() -> BikeTelemetry {
        .init(
            batteryLevel: .known(percent: 42),
            statusFlags: .init(isCharging: true),
            lastUpdated: .now
        )
    }
}
