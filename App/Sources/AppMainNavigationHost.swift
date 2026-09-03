import RideDashboard
import SwiftUI

struct AppMainNavigationHost: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var coordinator: AppNavigationCoordinator
    let featureStore: AppFeatureStore
    let settingsAccessory: () -> AnyView
    let onChangeBike: () -> Void

    var body: some View {
        NavigationStack(path: pathBinding) {
            RideDashboardScene(
                factory: featureStore.rideDashboardFactory,
                onNavigation: handleDashboardEvent,
                isNavigationActive: coordinator.state.rideNavigationMode == .mini,
                isPresentationActive: coordinator.state.activeSurfaces.contains(.dashboard)
            )
            .navigationDestination(for: AppRoute.self) { route in
                AppDestinationView(
                    route: route,
                    activeSurfaces: coordinator.state.activeSurfaces,
                    featureStore: featureStore,
                    settingsAccessory: settingsAccessory,
                    onIntent: coordinator.send,
                    onChangeBike: onChangeBike
                )
            }
        }
        .animation(navigationAnimation, value: coordinator.state.path)
    }

    private var pathBinding: Binding<[AppRoute]> {
        Binding(
            get: { coordinator.state.path },
            set: { coordinator.send(.replacePath($0)) }
        )
    }

    private func handleDashboardEvent(_ event: RideDashboardNavigationEvent) {
        coordinator.send(AppNavigationEventAdapter.intent(for: event))
    }

    private var navigationAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: Constants.reducedTransitionDuration)
            : .smooth(duration: Constants.transitionDuration)
    }

    private enum Constants {
        static let transitionDuration = 0.35
        static let reducedTransitionDuration = 0.12
    }
}
