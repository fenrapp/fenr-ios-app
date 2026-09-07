import Observation
import Testing

@MainActor
struct WatchNavigationObservationTests {
    @Test("Nested stack mutations and root replacement invalidate the root view's observed navigation state")
    func observesNestedNavigationState() {
        let coordinator = WatchNavigationCoordinator()
        coordinator.send(.setRoot(.dashboard))
        let pushed = WatchObservationRecorder()
        withObservationTracking {
            _ = coordinator.state.path
        } onChange: {
            pushed.record()
        }
        coordinator.send(.push(.settings))
        #expect(pushed.count == 1)
        #expect(coordinator.state.path == [.settings])

        let reset = WatchObservationRecorder()
        withObservationTracking {
            _ = coordinator.state.root
            _ = coordinator.state.path
        } onChange: {
            reset.record()
        }
        coordinator.send(.resetSetup)
        #expect(reset.count == 1)
        #expect(coordinator.state.root == .onboarding)
        #expect(coordinator.state.path.isEmpty)
    }
}
