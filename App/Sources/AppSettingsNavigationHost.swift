import SwiftUI

struct AppSettingsNavigationHost: View {
    let coordinator: AppNavigationCoordinator
    let featureStore: AppFeatureStore
    let settingsAccessory: () -> AnyView
    let onChangeBike: () -> Void

    var body: some View {
        NavigationStack(path: Binding(
            get: { coordinator.state.settingsPath },
            set: { path in
                guard coordinator.state.isSettingsPresented else { return }
                coordinator.send(.replacePath([.settings(.overview)] + path))
            }
        )) {
            destination(.settings(.overview))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            coordinator.send(.popToRoot)
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel(Text(.appCloseSettings))
                        .accessibilityIdentifier("settings.close")
                    }
                }
                .navigationDestination(for: AppRoute.self) { route in
                    destination(route)
                }
        }
    }

    private func destination(_ route: AppRoute) -> some View {
        AppDestinationView(
            route: route, activeSurfaces: coordinator.state.activeSurfaces,
            featureStore: featureStore, settingsAccessory: settingsAccessory,
            onIntent: coordinator.send, onChangeBike: onChangeBike
        )
    }
}
