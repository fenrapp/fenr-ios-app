#if os(iOS)
import SwiftUI

public struct RideDisplaySettingsView: View {
    private let viewModel: AppSettingsViewModel

    public init(viewModel: AppSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            RideDisplaySettingsContent(
                progressBarMode: viewModel.viewState.dashboardProgressBarMode,
                bikeBatteryDisplayMode: viewModel.viewState.dashboardBatteryIndicatorMode,
                deviceBatteryDisplayMode: viewModel.viewState.dashboardDeviceBatteryDisplayMode,
                temperatureDisplayMode: viewModel.viewState.dashboardTemperatureDisplayMode,
                speedSource: viewModel.viewState.speedSource,
                onSelectProgressBarMode: viewModel.selectDashboardProgressBarMode,
                onSelectProgressBarThickness: viewModel.selectDashboardProgressBarThickness,
                onSelectBikeBatteryDisplayMode: viewModel.selectDashboardBatteryIndicatorMode,
                onSelectDeviceBatteryDisplayMode: viewModel.selectDashboardDeviceBatteryDisplayMode,
                onSelectTemperatureDisplayMode: viewModel.selectDashboardTemperatureDisplayMode,
                onSelectSpeedSource: viewModel.selectSpeedSource,
                onRequestLocationAccess: viewModel.requestLocationAccess
            )
        }
        .navigationTitle(Text(.appSettingsRideDisplayTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
