import SwiftUI

public struct AppSettingsView: View {
    @ObservedObject private var viewModel: AppSettingsViewModel
    private let bikeLockModeTitle: String?
    private let onNavigation: (AppSettingsNavigationEvent) -> Void
    private let accessory: () -> AnyView

    public init(
        viewModel: AppSettingsViewModel,
        bikeLockModeTitle: String? = nil,
        onNavigation: @escaping (AppSettingsNavigationEvent) -> Void = { _ in },
        accessory: @escaping () -> AnyView = { AnyView(EmptyView()) }
    ) {
        self.viewModel = viewModel
        self.bikeLockModeTitle = bikeLockModeTitle
        self.onNavigation = onNavigation
        self.accessory = accessory
    }

    public var body: some View {
        Form {
            #if os(iOS)
            dashboardSection
            ridingSection
            bikeSection
            appSection
            advancedSection
            #else
            watchSettings
            #endif

            accessory()

            #if os(iOS)
            bikeManagementSection
            #endif
        }
        .navigationTitle(Text(.appSettingsTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var measurementSystemBinding: Binding<String> {
        .init(
            get: { viewModel.viewState.measurementSystem.selectedID },
            set: { viewModel.selectMeasurementSystem(id: $0) }
        )
    }

    private var batteryCapacityBinding: Binding<String> {
        .init(
            get: { viewModel.viewState.batteryCapacity.selectedID },
            set: { viewModel.selectBatteryPackCapacity(id: $0) }
        )
    }

    #if os(iOS)
    private var dashboardSection: some View {
        Section {
            SettingsNavigationRow(
                icon: "speedometer",
                iconTint: .blue,
                title: .appSettingsRideDisplayTitle,
                detail: viewModel.viewState.rideDisplay.detail,
                accessibilityIdentifier: "settings.rideDisplay",
                action: { onNavigation(.show(.rideDisplay)) }
            )
            SettingsNavigationRow(
                icon: "rectangle.stack.fill",
                iconTint: .indigo,
                title: .appSettingsDashboardCardsTitle,
                detail: viewModel.viewState.dashboardCards.detail,
                accessibilityIdentifier: "settings.dashboardCards",
                action: { onNavigation(.openDashboardCards) }
            )
        } header: {
            Text(.appSettingsDashboardSection)
        }
    }

    private var ridingSection: some View {
        Section {
            SettingsNavigationRow(
                icon: "location.north.line.fill",
                iconTint: .blue,
                title: .appSettingsNavigationTitle,
                detail: viewModel.viewState.navigation.detail,
                accessibilityIdentifier: "settings.navigation",
                action: { onNavigation(.show(.navigation)) }
            )
            SettingsNavigationRow(
                icon: "clock.arrow.circlepath",
                iconTint: .cyan,
                title: .appSettingsRideHistoryTitle,
                detail: .appSettingsRideHistoryDetail,
                accessibilityIdentifier: "settings.rideHistory",
                action: { onNavigation(.openRideHistory) }
            )
        } header: {
            Text(.appSettingsRidingSection)
        }
    }

    private var bikeSection: some View {
        Section {
            SettingsNavigationRow(
                icon: "slider.horizontal.3",
                iconTint: .orange,
                title: .appSettingsPowerModesTitle,
                detail: viewModel.viewState.powerModes.detail,
                accessibilityIdentifier: "settings.powerModes",
                action: { onNavigation(.openPowerModes) }
            )
            if viewModel.viewState.isBikeModelSelectionVisible {
                SettingsNavigationRow(
                    icon: "motorcycle",
                    iconTint: .purple,
                    title: .appSettingsBikeModelTitle,
                    detail: viewModel.viewState.powerTier.navigationDetail,
                    accessibilityIdentifier: "settings.bikeModel",
                    action: { onNavigation(.show(.bikeModel)) }
                )
            }
            SettingsNavigationRow(
                icon: "lock.fill",
                iconTint: .green,
                title: .appSettingsBikeLockTitle,
                verbatimDetail: bikeLockModeTitle ?? String(localized: .appSettingsUnavailable),
                accessibilityIdentifier: "settings.bikeLock",
                action: { onNavigation(.openBikeLock) }
            )
            SettingsNavigationRow(
                icon: "wrench.and.screwdriver.fill",
                iconTint: .blue,
                title: .appSettingsMaintenanceTitle,
                detail: .appSettingsMaintenanceDetail,
                accessibilityIdentifier: "settings.maintenance",
                action: { onNavigation(.openMaintenance) }
            )
            SettingsPickerRow(
                icon: "battery.75percent",
                iconTint: .teal,
                title: .appSettingsBatteryPackTitle,
                selection: batteryCapacityBinding,
                options: viewModel.viewState.batteryCapacity.options
            )
        } header: {
            Text(.appSettingsBikeSection)
        }
    }

    private var appSection: some View {
        Section {
            SettingsPickerRow(
                icon: "ruler",
                iconTint: .gray,
                title: .appSettingsMeasurementUnitsTitle,
                selection: measurementSystemBinding,
                options: viewModel.viewState.measurementSystem.options
            )
        } header: {
            Text(.appSettingsAppSection)
        }
    }

    private var advancedSection: some View {
        Section {
            SettingsNavigationRow(
                icon: "waveform.path.ecg",
                iconTint: .red,
                title: .appSettingsDiagnosticsTitle,
                detail: .appSettingsDiagnosticsDetail,
                accessibilityIdentifier: "settings.diagnostics",
                action: { onNavigation(.openDiagnostics) }
            )
        } header: {
            Text(.appSettingsAdvancedSection)
        }
    }

    private var bikeManagementSection: some View {
        Section {
            Button(role: .destructive) {
                onNavigation(.changeBike)
            } label: {
                Text(.appSettingsChangeBike)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("settings.changeBike")
        } footer: {
            Text(.appSettingsChangeBikeFooter)
        }
    }
    #else
    private var watchSettings: some View {
        Group {
            Section {
                Picker(.appSettingsMeasurementSystemPickerTitle, selection: measurementSystemBinding) {
                    ForEach(viewModel.viewState.measurementSystem.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text(.appSettingsUnitsSection)
            }

            Section {
                Picker(.appSettingsPackCapacityPickerTitle, selection: batteryCapacityBinding) {
                    ForEach(viewModel.viewState.batteryCapacity.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.navigationLink)

                Text(.appSettingsPackCapacityFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text(.appSettingsBatterySection)
            }
        }
    }
    #endif

}
