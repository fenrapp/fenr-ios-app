import SwiftUI

struct DashboardRideChrome<Content: View>: View {
    let state: RideDashboardViewState
    let deviceBattery: DashboardDeviceBatteryViewData
    let toggleDeviceBatteryDisplayMode: () -> Void
    let onSettings: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .overlay(alignment: .topLeading) {
                DashboardRideHeader(
                    deviceBattery: deviceBattery,
                    connectionNotice: state.connectionNotice,
                    toggleDeviceBatteryDisplayMode: toggleDeviceBatteryDisplayMode
                )
                .padding(DashboardRideChromeConstants.edgePadding)
            }
            .overlay(alignment: .topTrailing) {
                if state.hasTelemetry {
                    DashboardOdometerLabel(state: state.odometer)
                        .padding(DashboardRideChromeConstants.edgePadding)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if state.temperatureSummary.hasValues {
                    DashboardRideTemperatureSummary(state: state.temperatureSummary)
                        .padding(DashboardRideChromeConstants.edgePadding)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button(action: onSettings) {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(DashboardRideChromeConstants.edgePadding)
                .accessibilityIdentifier("dashboard.settings")
            }
    }
}

private enum DashboardRideChromeConstants {
    static let edgePadding: CGFloat = 16
}
