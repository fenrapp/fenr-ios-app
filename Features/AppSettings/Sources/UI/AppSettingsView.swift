import DesignSystem
import SwiftUI

public struct AppSettingsView: View {
    @ObservedObject private var viewModel: AppSettingsViewModel
    private let onOpenTelemetry: () -> Void
    private let onOpenDashboardCards: () -> Void
    private let onOpenPowerModes: () -> Void
    private let onOpenRideHistory: () -> Void
    private let bikeLockModeTitle: String?
    private let onOpenBikeLock: () -> Void
    private let accessory: () -> AnyView

    public init(
        viewModel: AppSettingsViewModel,
        onOpenTelemetry: @escaping () -> Void = {},
        onOpenDashboardCards: @escaping () -> Void = {},
        onOpenPowerModes: @escaping () -> Void = {},
        onOpenRideHistory: @escaping () -> Void = {},
        bikeLockModeTitle: String? = nil,
        onOpenBikeLock: @escaping () -> Void = {},
        accessory: @escaping () -> AnyView = { AnyView(EmptyView()) }
    ) {
        self.viewModel = viewModel
        self.onOpenTelemetry = onOpenTelemetry
        self.onOpenDashboardCards = onOpenDashboardCards
        self.onOpenPowerModes = onOpenPowerModes
        self.onOpenRideHistory = onOpenRideHistory
        self.bikeLockModeTitle = bikeLockModeTitle
        self.onOpenBikeLock = onOpenBikeLock
        self.accessory = accessory
    }

    public var body: some View {
        Form {
            #if os(iOS)
            Section("Ride dashboard") {
                Picker("Progress bar", selection: dashboardProgressBarModeBinding) {
                    ForEach(viewModel.viewState.dashboardProgressBarMode.selection.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.segmented)

                Text(viewModel.viewState.dashboardProgressBarMode.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Phone battery", selection: dashboardDeviceBatteryDisplayModeBinding) {
                    ForEach(viewModel.viewState.dashboardDeviceBatteryDisplayMode.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.menu)

                Text("Controls how the phone battery appears beside the dashboard clock.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle("Battery and inverter temperatures", isOn: showsDashboardTemperaturesBinding)

                Text("Shows available thermal readings on the ride dashboard.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Speed source", selection: speedSourceBinding) {
                    ForEach(viewModel.viewState.speedSource.selection.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.segmented)

                Text(viewModel.viewState.speedSource.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let locationPermission = viewModel.viewState.speedSource.locationPermission {
                    LocationPermissionRow(
                        status: locationPermission,
                        onRequestAccess: viewModel.requestLocationAccess
                    )
                }

                DashboardCardsNavigationRow(action: onOpenDashboardCards)
            }
            #endif

            #if os(iOS)
            Section("Bike power tier") {
                Picker("Declared model", selection: powerTierBinding) {
                    ForEach(viewModel.viewState.powerTier.selection.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.segmented)

                Text(viewModel.viewState.powerTier.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let evidence = viewModel.viewState.powerTier.evidence {
                    Text(evidence)
                        .font(.footnote)
                }
                Button {
                    viewModel.verifyPowerTierWithBike()
                } label: {
                    if viewModel.viewState.powerTier.isVerifying {
                        ProgressView()
                    } else {
                        Text("Verify with bike")
                    }
                }
                .disabled(!viewModel.viewState.powerTier.isVerifyEnabled)

                Text(
                    "The manual selection is only an expectation. "
                        + "Bike telemetry determines HP, TC and the effective tier."
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Bike") {
                PowerModesNavigationRow(
                    state: viewModel.viewState.powerModes,
                    action: onOpenPowerModes
                )
                if let bikeLockModeTitle {
                    Button(action: onOpenBikeLock) {
                        LabeledContent("Bike Lock", value: bikeLockModeTitle)
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section("Rides") {
                RideHistoryNavigationRow(action: onOpenRideHistory)
            }
            #endif

            Section("Units") {
                Picker("Measurement system", selection: measurementSystemBinding) {
                    ForEach(viewModel.viewState.measurementSystem.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(selectionPickerStyle)
            }

            Section("Battery") {
                #if os(iOS)
                Picker("Dashboard display", selection: dashboardBatteryIndicatorModeBinding) {
                    ForEach(viewModel.viewState.dashboardBatteryIndicatorMode.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.segmented)

                Text("Falls back to battery percentage until an estimated range is available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                #endif

                Picker("Pack capacity", selection: batteryPackCapacityBinding) {
                    ForEach(viewModel.viewState.batteryCapacity.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(selectionPickerStyle)

                Text("Used to estimate the remaining charging time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            #if os(iOS)
            Section("Diagnostics") {
                TelemetryActionRow(action: onOpenTelemetry)
            }
            #endif

            accessory()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var speedSourceBinding: Binding<String> {
        .init(
            get: { viewModel.viewState.speedSource.selection.selectedID },
            set: { viewModel.selectSpeedSource(id: $0) }
        )
    }

    private var dashboardProgressBarModeBinding: Binding<String> {
        .init(
            get: { viewModel.viewState.dashboardProgressBarMode.selection.selectedID },
            set: { viewModel.selectDashboardProgressBarMode(id: $0) }
        )
    }

    private var showsDashboardTemperaturesBinding: Binding<Bool> {
        .init(
            get: { viewModel.viewState.showsDashboardTemperatures },
            set: { viewModel.setShowsDashboardTemperatures($0) }
        )
    }

    private var dashboardDeviceBatteryDisplayModeBinding: Binding<String> {
        .init(
            get: { viewModel.viewState.dashboardDeviceBatteryDisplayMode.selectedID },
            set: { viewModel.selectDashboardDeviceBatteryDisplayMode(id: $0) }
        )
    }

    private var selectionPickerStyle: some PickerStyle {
        #if os(watchOS)
        NavigationLinkPickerStyle()
        #else
        SegmentedPickerStyle()
        #endif
    }

    private var measurementSystemBinding: Binding<String> {
        .init(
            get: { viewModel.viewState.measurementSystem.selectedID },
            set: { viewModel.selectMeasurementSystem(id: $0) }
        )
    }

    private var batteryPackCapacityBinding: Binding<String> {
        .init(
            get: { viewModel.viewState.batteryCapacity.selectedID },
            set: { viewModel.selectBatteryPackCapacity(id: $0) }
        )
    }

    private var dashboardBatteryIndicatorModeBinding: Binding<String> {
        .init(
            get: { viewModel.viewState.dashboardBatteryIndicatorMode.selectedID },
            set: { viewModel.selectDashboardBatteryIndicatorMode(id: $0) }
        )
    }

    private var powerTierBinding: Binding<String> {
        .init(
            get: { viewModel.viewState.powerTier.selection.selectedID },
            set: { viewModel.selectDeclaredPowerTier(id: $0) }
        )
    }

}
