#if os(iOS)
import SwiftUI

public struct RideDisplaySettingsView: View {
    @ObservedObject private var viewModel: AppSettingsViewModel

    public init(viewModel: AppSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            RideDisplaySettingsContent(
                progressBarMode: viewModel.viewState.dashboardProgressBarMode,
                bikeBatteryDisplayMode: viewModel.viewState.dashboardBatteryIndicatorMode,
                deviceBatteryDisplayMode: viewModel.viewState.dashboardDeviceBatteryDisplayMode,
                showsTemperatures: viewModel.viewState.showsDashboardTemperatures,
                speedSource: viewModel.viewState.speedSource,
                onSelectProgressBarMode: viewModel.selectDashboardProgressBarMode,
                onSelectBikeBatteryDisplayMode: viewModel.selectDashboardBatteryIndicatorMode,
                onSelectDeviceBatteryDisplayMode: viewModel.selectDashboardDeviceBatteryDisplayMode,
                onSetShowsTemperatures: viewModel.setShowsDashboardTemperatures,
                onSelectSpeedSource: viewModel.selectSpeedSource,
                onRequestLocationAccess: viewModel.requestLocationAccess
            )
        }
        .navigationTitle("Ride Display")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}
#endif
