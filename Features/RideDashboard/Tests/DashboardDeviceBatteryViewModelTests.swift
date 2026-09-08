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

    @Test("Deinit stops active battery monitoring")
    func deinitStopsActiveBatteryMonitoring() {
        let monitor = TestDashboardDeviceBatteryMonitor()
        var viewModel: DashboardDeviceBatteryViewModel? = makeViewModel(monitor: monitor)

        viewModel?.start()
        viewModel = nil

        #expect(monitor.stopCount == 1)
    }

    @Test("Stop is idempotent across repeated lifecycle events")
    func stopIsIdempotentAcrossRepeatedLifecycleEvents() {
        let monitor = TestDashboardDeviceBatteryMonitor()
        let viewModel = makeViewModel(monitor: monitor)

        viewModel.start()
        viewModel.stop()
        viewModel.stop()
        #expect(monitor.stopCount == 1)

        viewModel.start()
        viewModel.stop()
        #expect(monitor.stopCount == 2)
    }

    @Test("Starts with icon and percentage and persists visible display mode cycles")
    func persistsDisplayMode() async {
        let monitor = TestDashboardDeviceBatteryMonitor()
        let repository = TestDashboardDeviceBatterySettingsRepository()
        let viewModel = makeViewModel(monitor: monitor, repository: repository)

        viewModel.start()
        #expect(viewModel.viewState.showsIcon)
        #expect(viewModel.viewState.showsPercentage)
        #expect(await waitUntil { viewModel.viewState.canChangeDisplayMode })

        viewModel.toggleDisplayMode()

        #expect(!viewModel.viewState.showsIcon)
        #expect(viewModel.viewState.showsPercentage)
        #expect(await waitUntil { await repository.load().dashboardDeviceBatteryDisplayMode == .textOnly })

        viewModel.toggleDisplayMode()
        viewModel.toggleDisplayMode()
        viewModel.toggleDisplayMode()

        #expect(!viewModel.viewState.showsIcon)
        #expect(viewModel.viewState.showsPercentage)
        #expect(await waitUntil { await repository.load().dashboardDeviceBatteryDisplayMode == .textOnly })

        viewModel.stop()
        viewModel.start()
        #expect(await waitUntil {
            !viewModel.viewState.showsIcon && viewModel.viewState.showsPercentage
        })

        viewModel.toggleDisplayMode()
        #expect(viewModel.viewState.showsIcon)
        #expect(!viewModel.viewState.showsPercentage)
        #expect(await waitUntil { await repository.load().dashboardDeviceBatteryDisplayMode == .iconOnly })
    }

    @Test("Failed battery display updates roll back and show an error")
    func failedDisplayModeRollsBack() async {
        let repository = TestDashboardDeviceBatterySettingsRepository()
        await repository.setFailsUpdating(true)
        let viewModel = makeViewModel(monitor: .init(), repository: repository)
        viewModel.start()
        #expect(await waitUntil { viewModel.viewState.canChangeDisplayMode })
        viewModel.toggleDisplayMode()
        #expect(!viewModel.viewState.showsIcon)
        #expect(await waitUntil { viewModel.viewState.errorText != nil })
        #expect(viewModel.viewState.showsIcon && viewModel.viewState.showsPercentage)
        await repository.setFailsUpdating(false)
        viewModel.toggleDisplayMode()
        #expect(await waitUntil { await repository.load().dashboardDeviceBatteryDisplayMode == .textOnly })
        #expect(viewModel.viewState.errorText == nil)
        viewModel.stop()
    }

    @Test("Queued display updates preserve order and ignore older observations")
    func queuedUpdatesIgnoreStaleSnapshots() async {
        let repository = TestDashboardDeviceBatterySettingsRepository()
        await repository.blockNextUpdate()
        let viewModel = makeViewModel(monitor: .init(), repository: repository)
        viewModel.start()
        #expect(await waitUntil { viewModel.viewState.canChangeDisplayMode })
        viewModel.toggleDisplayMode()
        #expect(await waitUntil { await repository.hasBlockedUpdate() })
        viewModel.toggleDisplayMode()
        #expect(viewModel.viewState.showsIcon && !viewModel.viewState.showsPercentage)
        await repository.send(.init(settings: .init().scoped(toVIN: "FENRTEST000000001"), revision: 0))
        await repository.resumeUpdate()
        #expect(await waitUntil { await repository.load().dashboardDeviceBatteryDisplayMode == .iconOnly })
        #expect(await repository.changes == [
            .dashboardDeviceBatteryDisplayMode(.textOnly), .dashboardDeviceBatteryDisplayMode(.iconOnly)
        ])
        #expect(viewModel.viewState.showsIcon && !viewModel.viewState.showsPercentage)
        viewModel.stop()
    }

    @Test("Stop cancels queued battery settings and ignores a late update")
    func stopCancelsPendingDisplayUpdates() async {
        let repository = TestDashboardDeviceBatterySettingsRepository()
        await repository.blockNextUpdate()
        let viewModel = makeViewModel(monitor: .init(), repository: repository)
        viewModel.start()
        #expect(await waitUntil { viewModel.viewState.canChangeDisplayMode })
        viewModel.toggleDisplayMode()
        #expect(await waitUntil { await repository.hasBlockedUpdate() })
        viewModel.toggleDisplayMode()
        viewModel.stop()
        await repository.resumeUpdate()
        viewModel.start()
        #expect(await waitUntil { viewModel.viewState.showsIcon && viewModel.viewState.showsPercentage })
        #expect(await repository.changes == [.dashboardDeviceBatteryDisplayMode(.textOnly)])
        #expect(viewModel.viewState.errorText == nil)
        viewModel.stop()
    }

    private func makeViewModel(
        monitor: TestDashboardDeviceBatteryMonitor,
        repository: TestDashboardDeviceBatterySettingsRepository = .init()
    ) -> DashboardDeviceBatteryViewModel {
        DashboardDeviceBatteryViewModel(
            monitor: monitor,
            observeSettings: ObserveAppSettingsUseCase(repository: repository),
            updateSettings: UpdateAppSettingsUseCase(repository: repository),
            mapper: DashboardDeviceBatteryMapper()
        )
    }
}
