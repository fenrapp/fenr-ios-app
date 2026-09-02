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
            dataSection
            #else
            watchSettings
            #endif

            accessory()
        }
        .navigationTitle("Settings")
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
        Section("Dashboard") {
            SettingsNavigationRow(
                icon: "speedometer",
                iconTint: .blue,
                title: "Ride Display",
                detail: viewModel.viewState.rideDisplay.detail,
                accessibilityIdentifier: "settings.rideDisplay",
                action: onOpenRideDisplay
            )
            SettingsNavigationRow(
                icon: "rectangle.stack.fill",
                iconTint: .indigo,
                title: "Dashboard Cards",
                detail: viewModel.viewState.dashboardCards.detail,
                accessibilityIdentifier: "settings.dashboardCards",
                action: onOpenDashboardCards
            )
        }
    }

    private var bikeSection: some View {
        Section("Bike") {
            SettingsNavigationRow(
                icon: "slider.horizontal.3",
                iconTint: .orange,
                title: "Power Modes",
                detail: viewModel.viewState.powerModes.detail,
                accessibilityIdentifier: "settings.powerModes",
                action: onOpenPowerModes
            )
            SettingsNavigationRow(
                icon: "motorcycle",
                iconTint: .purple,
                title: "Bike Model",
                detail: viewModel.viewState.powerTier.navigationDetail,
                accessibilityIdentifier: "settings.bikeModel",
                action: onOpenBikeModel
            )
            SettingsNavigationRow(
                icon: "lock.fill",
                iconTint: .green,
                title: "Bike Lock",
                detail: bikeLockModeTitle ?? "Unavailable",
                accessibilityIdentifier: "settings.bikeLock",
                action: onOpenBikeLock
            )
            SettingsPickerRow(
                icon: "battery.75percent",
                iconTint: .teal,
                title: "Battery Pack",
                selection: batteryCapacityBinding,
                options: viewModel.viewState.batteryCapacity.options
            )
        }
    }

    private var appSection: some View {
        Section("App") {
            SettingsPickerRow(
                icon: "ruler",
                iconTint: .gray,
                title: "Measurement Units",
                selection: measurementSystemBinding,
                options: viewModel.viewState.measurementSystem.options
            )
        }
    }

    private var dataSection: some View {
        Section("Data & Diagnostics") {
            SettingsNavigationRow(
                icon: "clock.arrow.circlepath",
                iconTint: .cyan,
                title: "Ride History",
                detail: "Saved rides",
                accessibilityIdentifier: "settings.rideHistory",
                action: onOpenRideHistory
            )
            SettingsNavigationRow(
                icon: "waveform.path.ecg",
                iconTint: .red,
                title: "Diagnostics",
                detail: "Telemetry and health",
                accessibilityIdentifier: "settings.diagnostics",
                action: onOpenTelemetry
            )
        }
    }
    #else
    private var watchSettings: some View {
        Group {
            Section("Units") {
                Picker("Measurement system", selection: measurementSystemBinding) {
                    ForEach(viewModel.viewState.measurementSystem.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section("Battery") {
                Picker("Pack capacity", selection: batteryCapacityBinding) {
                    ForEach(viewModel.viewState.batteryCapacity.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.navigationLink)

                Text("Used to estimate the remaining charging time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    #endif

}
