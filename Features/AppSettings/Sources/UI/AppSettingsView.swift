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
            RideDashboardSettingsSection(
                progressBarMode: viewModel.viewState.dashboardProgressBarMode,
                deviceBatteryDisplayMode: viewModel.viewState.dashboardDeviceBatteryDisplayMode,
                showsTemperatures: viewModel.viewState.showsDashboardTemperatures,
                speedSource: viewModel.viewState.speedSource,
                onSelectProgressBarMode: viewModel.selectDashboardProgressBarMode,
                onSelectDeviceBatteryDisplayMode: viewModel.selectDashboardDeviceBatteryDisplayMode,
                onSetShowsTemperatures: viewModel.setShowsDashboardTemperatures,
                onSelectSpeedSource: viewModel.selectSpeedSource,
                onRequestLocationAccess: viewModel.requestLocationAccess,
                onOpenDashboardCards: onOpenDashboardCards
            )
            #endif

            #if os(iOS)
            PowerTierSettingsSection(
                state: viewModel.viewState.powerTier,
                onSelectDeclaredTier: viewModel.selectDeclaredPowerTier,
                onVerify: viewModel.verifyPowerTierWithBike
            )

            Section("Bike") {
                SettingsNavigationRow(
                    icon: "slider.horizontal.3",
                    title: "Power modes",
                    detail: viewModel.viewState.powerModes.detail,
                    accessibilityIdentifier: "settings.powerModes",
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
                SettingsNavigationRow(
                    icon: "clock.arrow.circlepath",
                    title: "Ride history",
                    detail: "Review saved rides and recent comparisons",
                    accessibilityIdentifier: "settings.rideHistory",
                    action: onOpenRideHistory
                )
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

            BatterySettingsSection(
                dashboardIndicatorMode: viewModel.viewState.dashboardBatteryIndicatorMode,
                capacity: viewModel.viewState.batteryCapacity,
                onSelectDashboardIndicatorMode: viewModel.selectDashboardBatteryIndicatorMode,
                onSelectCapacity: viewModel.selectBatteryPackCapacity
            )

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

}
