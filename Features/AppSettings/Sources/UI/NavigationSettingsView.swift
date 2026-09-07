#if os(iOS)
import SwiftUI

public struct NavigationSettingsView: View {
    private let viewModel: AppSettingsViewModel
    private let onNavigation: (AppSettingsNavigationEvent) -> Void

    public init(
        viewModel: AppSettingsViewModel,
        onNavigation: @escaping (AppSettingsNavigationEvent) -> Void
    ) {
        self.viewModel = viewModel
        self.onNavigation = onNavigation
    }

    public var body: some View {
        Form {
            focusSection
            mapSection
            appearanceSection
        }
        .navigationTitle(Text(.appSettingsNavigationTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var focusSection: some View {
        Section {
            Toggle(
                .appSettingsNavigationShowGuidance,
                isOn: Binding(
                    get: { viewModel.viewState.navigationSettings.showsGuidanceInFocus },
                    set: { isVisible in
                        viewModel.setShowsGuidanceInFocus(isVisible)
                    }
                )
            )
            Toggle(
                .appSettingsNavigationShowRoads,
                isOn: Binding(
                    get: { viewModel.viewState.navigationSettings.showsRoadsInFocus },
                    set: { isVisible in
                        viewModel.setShowsRoadsInFocus(isVisible)
                    }
                )
            )
        } header: {
            Text(.appSettingsNavigationFocusSection)
        } footer: {
            Text(.appSettingsNavigationFocusFooter)
        }
    }

    private var mapSection: some View {
        Section {
            Toggle(
                .appSettingsNavigationShowCompass,
                isOn: Binding(
                    get: { viewModel.viewState.navigationSettings.showsCompassRing },
                    set: { isVisible in
                        viewModel.setShowsCompassRing(isVisible)
                    }
                )
            )
        } header: {
            Text(.appSettingsNavigationMapSection)
        } footer: {
            Text(.appSettingsNavigationCompassFooter)
        }
    }

    private var appearanceSection: some View {
        Section {
            SettingsNavigationRow(
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                iconTint: .blue,
                title: .appSettingsNavigationAppearanceTitle,
                detail: .appSettingsNavigationAppearanceDetail,
                accessibilityIdentifier: "settings.navigation.appearance",
                action: { onNavigation(.show(.navigationAppearance)) }
            )
        }
    }
}
#endif
