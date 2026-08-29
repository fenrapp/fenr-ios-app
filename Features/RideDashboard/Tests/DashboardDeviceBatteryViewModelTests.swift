@testable import RideDashboard
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("Dashboard device battery")
struct DashboardDeviceBatteryViewModelTests {
    @Test("Formats charging, low, and unavailable iPhone battery states")
    func mapsBatteryStates() async {
        let monitor = TestDashboardDeviceBatteryMonitor()
        let viewModel = makeViewModel(monitor: monitor)

        viewModel.start()
        #expect(monitor.startCount == 1)

        monitor.send(.init(level: 0.524, isCharging: true))
        #expect(await waitUntil { viewModel.viewState.percentageText == "52%" })
        #expect(viewModel.viewState.emphasis == .charging)
        #expect(viewModel.viewState.accessibilityLabel == "iPhone battery 52 percent, charging")

        monitor.send(.init(level: 0.2, isCharging: false))
        #expect(await waitUntil { viewModel.viewState.percentageText == "20%" })
        #expect(viewModel.viewState.emphasis == .low)

        monitor.send(.init(level: nil, isCharging: false))
        #expect(await waitUntil { viewModel.viewState.emphasis == .unavailable })
        #expect(viewModel.viewState.accessibilityLabel == "iPhone battery unavailable")

        viewModel.stop()
        #expect(monitor.stopCount == 1)
    }

    @Test("Starts once and can restart after stopping")
    func ownsMonitoringLifecycle() {
        let monitor = TestDashboardDeviceBatteryMonitor()
        let viewModel = makeViewModel(monitor: monitor)

        viewModel.start()
        viewModel.start()
        #expect(monitor.startCount == 1)

        viewModel.stop()
        viewModel.start()
        #expect(monitor.startCount == 2)
        #expect(monitor.stopCount == 1)
    }

    @Test("Starts with the icon and persists display mode toggles")
    func persistsDisplayMode() async {
        let monitor = TestDashboardDeviceBatteryMonitor()
        let repository = TestDashboardDeviceBatterySettingsRepository()
        let viewModel = makeViewModel(monitor: monitor, repository: repository)

        viewModel.start()
        #expect(viewModel.viewState.displayMode == .icon)

        viewModel.toggleDisplayMode()

        #expect(viewModel.viewState.displayMode == .text)
        #expect(await waitUntil { await repository.load().dashboardDeviceBatteryDisplayMode == .text })

        viewModel.toggleDisplayMode()
        viewModel.toggleDisplayMode()
        viewModel.toggleDisplayMode()

        #expect(viewModel.viewState.displayMode == .icon)
        #expect(await waitUntil { await repository.load().dashboardDeviceBatteryDisplayMode == .icon })

        viewModel.stop()
        viewModel.start()
        #expect(await waitUntil { viewModel.viewState.displayMode == .icon })

        viewModel.toggleDisplayMode()
        #expect(viewModel.viewState.displayMode == .text)
        #expect(await waitUntil { await repository.load().dashboardDeviceBatteryDisplayMode == .text })
    }

    private func makeViewModel(
        monitor: TestDashboardDeviceBatteryMonitor,
        repository: TestDashboardDeviceBatterySettingsRepository = .init()
    ) -> DashboardDeviceBatteryViewModel {
        DashboardDeviceBatteryViewModel(
            monitor: monitor,
            loadSettings: LoadAppSettingsUseCase(repository: repository),
            saveSettings: SaveAppSettingsUseCase(repository: repository)
        )
    }
}
