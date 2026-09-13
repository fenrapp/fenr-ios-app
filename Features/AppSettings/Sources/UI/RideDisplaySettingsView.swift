#if os(iOS)
import SwiftUI

public struct RideDisplaySettingsView: View {
    let state: RideDisplayOverviewViewState
    let onNavigation: (AppSettingsNavigationEvent) -> Void

    public init(
        state: RideDisplayOverviewViewState,
        onNavigation: @escaping (AppSettingsNavigationEvent) -> Void
    ) {
        self.state = state
        self.onNavigation = onNavigation
    }

    public var body: some View {
        Form {
            RideDisplaySettingsContent(state: state, onNavigation: onNavigation)
        }
        .navigationTitle(Text(.appSettingsRideDisplayTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
