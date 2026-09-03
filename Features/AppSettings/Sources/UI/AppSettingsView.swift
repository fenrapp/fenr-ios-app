import SwiftUI

public struct AppSettingsView: View {
    @ObservedObject private var viewModel: AppSettingsViewModel
    private let onOpenTelemetry: () -> Void
    private let onOpenRideDisplay: () -> Void
    private let onOpenDashboardCards: () -> Void
    private let onOpenPowerModes: () -> Void
    private let onOpenBikeModel: () -> Void
    private let onOpenRideHistory: () -> Void
    private let bikeLockModeTitle: String?
    private let onOpenBikeLock: () -> Void
    private let accessory: () -> AnyView

    public init(
        viewModel: AppSettingsViewModel,
        onOpenTelemetry: @escaping () -> Void = {},
        onOpenRideDisplay: @escaping () -> Void = {},
        onOpenDashboardCards: @escaping () -> Void = {},
        onOpenPowerModes: @escaping () -> Void = {},
        onOpenBikeModel: @escaping () -> Void = {},
        onOpenRideHistory: @escaping () -> Void = {},
        bikeLockModeTitle: String? = nil,
        onOpenBikeLock: @escaping () -> Void = {},
        accessory: @escaping () -> AnyView = { AnyView(EmptyView()) }
    ) {
        self.viewModel = viewModel
        self.onOpenTelemetry = onOpenTelemetry
        self.onOpenRideDisplay = onOpenRideDisplay
        self.onOpenDashboardCards = onOpenDashboardCards
        self.onOpenPowerModes = onOpenPowerModes
        self.onOpenBikeModel = onOpenBikeModel
        self.onOpenRideHistory = onOpenRideHistory
        self.bikeLockModeTitle = bikeLockModeTitle
        self.onOpenBikeLock = onOpenBikeLock
        self.accessory = accessory
    }

    public var body: some View {
        Form {
            #if os(iOS)
            dashboardSection
            bikeSection
            appSection
            advancedSection
            #else
            watchSettings
            #endif

            accessory()
        }
        .navigationTitle(Text(.appSettingsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
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
                action: onOpenRideDisplay
            )
            SettingsNavigationRow(
                icon: "rectangle.stack.fill",
                iconTint: .indigo,
                title: .appSettingsDashboardCardsTitle,
                detail: viewModel.viewState.dashboardCards.detail,
                accessibilityIdentifier: "settings.dashboardCards",
                action: onOpenDashboardCards
            )
            SettingsNavigationRow(
                icon: "clock.arrow.circlepath",
                iconTint: .cyan,
                title: .appSettingsRideHistoryTitle,
                detail: .appSettingsRideHistoryDetail,
                accessibilityIdentifier: "settings.rideHistory",
                action: onOpenRideHistory
            )
        } header: {
            Text(.appSettingsDashboardSection)
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
                action: onOpenPowerModes
            )
            if viewModel.viewState.isBikeModelSelectionVisible {
                SettingsNavigationRow(
                    icon: "motorcycle",
                    iconTint: .purple,
                    title: .appSettingsBikeModelTitle,
                    detail: viewModel.viewState.powerTier.navigationDetail,
                    accessibilityIdentifier: "settings.bikeModel",
                    action: onOpenBikeModel
                )
            }
            SettingsNavigationRow(
                icon: "lock.fill",
                iconTint: .green,
                title: .appSettingsBikeLockTitle,
                verbatimDetail: bikeLockModeTitle ?? String(localized: .appSettingsUnavailable),
                accessibilityIdentifier: "settings.bikeLock",
                action: onOpenBikeLock
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
                action: onOpenTelemetry
            )
        } header: {
            Text(.appSettingsAdvancedSection)
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
