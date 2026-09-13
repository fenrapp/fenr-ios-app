import SwiftUI

public struct AppSettingsScene: View {
    private let destination: AppSettingsDestination
    private let viewModel: AppSettingsViewModel
    private let bikeLockModeTitle: String?
    private let isPresentationActive: Bool
    private let onNavigation: (AppSettingsNavigationEvent) -> Void
    private let accessory: () -> AnyView

    public init(
        destination: AppSettingsDestination,
        viewModel: AppSettingsViewModel,
        bikeLockModeTitle: String? = nil,
        isPresentationActive: Bool,
        onNavigation: @escaping (AppSettingsNavigationEvent) -> Void,
        accessory: @escaping () -> AnyView = { AnyView(EmptyView()) }
    ) {
        self.destination = destination
        self.viewModel = viewModel
        self.bikeLockModeTitle = bikeLockModeTitle
        self.isPresentationActive = isPresentationActive
        self.onNavigation = onNavigation
        self.accessory = accessory
    }

    public var body: some View {
        destinationView
            .alert(
                Text(.appSettingsSaveErrorTitle),
                isPresented: Binding(
                    get: { viewModel.settingsSaveError != nil },
                    set: { if !$0 { viewModel.dismissSettingsSaveError() } }
                )
            ) {
                Button(.appSettingsSaveErrorDismiss) { viewModel.dismissSettingsSaveError() }
            } message: {
                Text(verbatim: viewModel.settingsSaveError ?? "")
            }
            .task { synchronizePresentation() }
            .onChange(of: isPresentationActive) { synchronizePresentation() }
            .onDisappear {
                if ownsPresentationLifecycle, !isPresentationActive { viewModel.stop() }
            }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch destination {
        case .overview:
            AppSettingsView(
                viewModel: viewModel,
                bikeLockModeTitle: bikeLockModeTitle,
                onNavigation: onNavigation,
                accessory: accessory
            )
        #if os(iOS)
        case .rideDisplay:
            RideDisplaySettingsView(state: viewModel.viewState.rideDisplayOverview, onNavigation: onNavigation)
        case .rideProgressBar:
            RideProgressBarSettingsView(
                state: viewModel.viewState.dashboardProgressBarMode,
                onSelectMode: viewModel.selectDashboardProgressBarMode,
                onSelectThickness: viewModel.selectDashboardProgressBarThickness
            )
        case .rideBatteryDisplay:
            RideBatteryDisplaySettingsView(
                bikeBattery: viewModel.viewState.dashboardBatteryIndicatorMode,
                phoneBattery: viewModel.viewState.dashboardDeviceBatteryDisplayMode,
                onSelectBikeBattery: viewModel.selectDashboardBatteryIndicatorMode,
                onSelectPhoneBattery: viewModel.selectDashboardDeviceBatteryDisplayMode
            )
        case .rideInformation:
            RideInformationSettingsView(
                showsBikeHours: viewModel.viewState.showsBikeHours,
                temperatures: viewModel.viewState.dashboardTemperatureDisplayMode,
                onSetShowsBikeHours: viewModel.setShowsBikeHours,
                onSelectTemperatures: viewModel.selectDashboardTemperatureDisplayMode
            )
        case .rideSpeed:
            RideSpeedSettingsView(
                state: viewModel.viewState.speedSource,
                onSelect: viewModel.selectSpeedSource,
                onRequestLocationAccess: viewModel.requestLocationAccess
            )
        case .navigation:
            NavigationSettingsView(viewModel: viewModel, onNavigation: onNavigation)
        case .navigationAppearance:
            NavigationAppearanceSettingsView(viewModel: viewModel)
        case .liveActivities:
            LiveActivitySettingsView(viewModel: viewModel)
        case .bikeModel:
            BikeModelSettingsView(viewModel: viewModel)
        case .acknowledgments:
            AcknowledgmentsSettingsView(onNavigation: onNavigation)
        #else
        case .rideDisplay, .rideProgressBar, .rideBatteryDisplay, .rideInformation, .rideSpeed,
             .navigation, .navigationAppearance, .bikeModel, .liveActivities, .acknowledgments:
            EmptyView()
        #endif
        }
    }

    private func synchronizePresentation() {
        guard ownsPresentationLifecycle else { return }
        if isPresentationActive {
            viewModel.start()
        } else {
            viewModel.stop()
        }
    }

    private var ownsPresentationLifecycle: Bool {
        destination == .overview
    }
}
