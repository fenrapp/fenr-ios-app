import BikeDomain
import Testing
@testable import WatchDashboard

@MainActor
struct WatchDashboardViewModelTests {
    @Test("charging monitoring is started only while charging")
    func chargingMonitoringFollowsRunState() async {
        let repository = WatchDashboardRepository()
        let viewModel = WatchDashboardViewModel(
            useCases: .init(repository: repository, batteryHealthRepository: repository)
        )

        viewModel.start()
        await repository.send(.init(lastUpdated: .now))
        try? await Task.sleep(for: .milliseconds(20))
        #expect(await repository.startMonitoringCalls == 0)

        await repository.send(.init(
            batteryLevel: .init(percent: 42),
            statusFlags: .init(isCharging: true),
            lastUpdated: .now
        ))
        try? await Task.sleep(for: .milliseconds(20))
        #expect(await repository.startMonitoringCalls == 1)
        #expect(viewModel.viewState.mode == .charging)
    }
}
