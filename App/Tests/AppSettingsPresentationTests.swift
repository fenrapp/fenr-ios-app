import Foundation
import Testing

@MainActor
@Suite("Full screen settings navigation")
struct AppSettingsPresentationTests {
    @Test("Settings uses a separate stack and closes back to the dashboard")
    func presentsAndDismisses() {
        let navigation = AppNavigationCoordinator()
        navigation.send(.setRoot(.dashboard))
        navigation.send(.push(.settings(.overview)))
        #expect(navigation.state.isSettingsPresented)
        #expect(navigation.state.dashboardPath.isEmpty)
        #expect(navigation.state.settingsPath.isEmpty)
        navigation.send(.push(.settings(.rideProgressBar)))
        #expect(navigation.state.settingsPath == [.settings(.rideDisplay), .settings(.rideProgressBar)])
        navigation.send(.pop(ifTop: nil))
        #expect(navigation.state.settingsPath == [.settings(.rideDisplay)])
        navigation.send(.popToRoot)
        #expect(!navigation.state.isSettingsPresented)
        #expect(navigation.state.activeSurfaces == [.dashboard])
    }

    @Test("Direct display details include their complete parent hierarchy")
    func canonicalizesNestedDetails() {
        let navigation = AppNavigationCoordinator()
        navigation.send(.setRoot(.dashboard))
        navigation.send(.replacePath([.settings(.rideSpeed)]))
        #expect(navigation.state.path == [
            .settings(.overview), .settings(.rideDisplay), .settings(.rideSpeed)
        ])
    }

    @Test("Full screen map suspends the settings cover and closing restores its path")
    func mapDoesNotStayBehindCover() {
        let navigation = AppNavigationCoordinator()
        navigation.send(.setRoot(.dashboard))
        navigation.send(.push(.settings(.rideInformation)))
        let path = navigation.state.path
        navigation.send(.showRideNavigation(nil))
        #expect(!navigation.state.isSettingsPresented)
        #expect(navigation.state.path == path)
        navigation.send(.closeRideNavigation)
        #expect(navigation.state.isSettingsPresented)
        #expect(navigation.state.path == path)
        navigation.send(.resetSetup)
        #expect(!navigation.state.isSettingsPresented)
        #expect(navigation.state.settingsPath.isEmpty)
    }
}
