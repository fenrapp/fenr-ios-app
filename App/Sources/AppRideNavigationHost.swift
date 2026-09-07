import RideNavigation
import SwiftUI

struct AppRideNavigationHost: View {
    let coordinator: AppNavigationCoordinator
    let featureStore: AppFeatureStore

    var body: some View {
        if coordinator.state.rideNavigationMode != .hidden {
            RideNavigationScene(
                factory: featureStore.rideNavigationFactory,
                presentationMode: presentationMode,
                importedURL: coordinator.state.rideNavigationResource?.url,
                importedURLToken: coordinator.state.rideNavigationResource?.id,
                onNavigation: handleNavigationEvent
            )
            .zIndex(1)
        }
    }

    private var presentationMode: RideNavigationPresentationMode {
        switch coordinator.state.rideNavigationMode {
        case .hidden: .hidden
        case .fullScreen: .fullScreen
        case .mini: .mini
        }
    }

    private func handleNavigationEvent(_ event: RideNavigationPresentationEvent) {
        switch event {
        case .close:
            coordinator.send(.closeRideNavigation)
        case .minimize:
            coordinator.send(.minimizeRideNavigation)
        case .expand:
            coordinator.send(.expandRideNavigation)
        }
    }
}
