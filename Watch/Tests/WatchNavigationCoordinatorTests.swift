import Testing
import WatchDashboard

@MainActor
@Suite("Watch navigation coordinator")
struct WatchNavigationCoordinatorTests {
    @Test("Transitions through loading, onboarding, dashboard, settings, and back")
    func rootAndStackTransitions() {
        let coordinator = WatchNavigationCoordinator()
        #expect(coordinator.state.root == .loading)

        coordinator.send(.setRoot(.onboarding))
        #expect(coordinator.state.root == .onboarding)
        coordinator.send(.setRoot(.dashboard))
        coordinator.send(.push(.settings))
        coordinator.send(.push(.settings))
        #expect(coordinator.state.path == [.settings])
        coordinator.send(.pop)
        #expect(coordinator.state.path.isEmpty)
    }

    @Test("Changing bike clears the Watch stack")
    func changeBikeReset() {
        let coordinator = WatchNavigationCoordinator()
        coordinator.send(.setRoot(.dashboard))
        coordinator.send(.push(.settings))
        coordinator.send(.resetSetup)

        #expect(coordinator.state.root == .onboarding)
        #expect(coordinator.state.path.isEmpty)
    }

    @Test("Dashboard events map to typed navigation")
    func dashboardEvents() {
        #expect(WatchNavigationEventAdapter.intent(for: .openSettings) == .push(.settings))
        #expect(WatchNavigationEventAdapter.intent(for: .changeBike) == nil)
    }
}
