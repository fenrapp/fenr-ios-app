import DesignSystem
import SwiftUI

struct DashboardRideChrome<Content: View>: View {
    let state: RideDashboardViewState
    let deviceBattery: DashboardDeviceBatteryViewData
    let toggleDeviceBatteryDisplayMode: () -> Void
    let onSettings: () -> Void
    let showsSettingsShortcut: Bool
    let headerColumnWidth: CGFloat?
    var bottomLeadingAccessory: () -> AnyView = { AnyView(EmptyView()) }
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .overlay(alignment: .top) {
                HStack(alignment: .firstTextBaseline, spacing: DesignSpace.small) {
                    DashboardRideHeader(
                        deviceBattery: deviceBattery,
                        connectionNotice: state.connectionNotice,
                        toggleDeviceBatteryDisplayMode: toggleDeviceBatteryDisplayMode
                    )
                    .frame(width: headerContentWidth, alignment: .leading)
                    Spacer(minLength: DesignSpace.small)
                    if state.hasTelemetry {
                        HStack(alignment: .firstTextBaseline, spacing: DesignSpace.small) {
                            DashboardOdometerLabel(state: state.odometer)
                            if let hours = state.experimentalHours {
                                DashboardExperimentalHoursLabel(state: hours)
                            }
                        }
                    }
                }
                .padding(DashboardRideChromeConstants.edgePadding)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: DesignSpace.small) {
                    bottomLeadingAccessory()
                    if state.temperatureSummary.hasValues {
                        DashboardRideTemperatureSummary(state: state.temperatureSummary)
                    }
                }
                .padding(DashboardRideChromeConstants.edgePadding)
            }
            .overlay(alignment: .bottomTrailing) {
                if showsSettingsShortcut {
                    Button(action: onSettings) {
                        Label(.rideDashboardHeaderSettings, systemImage: "gearshape.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(DashboardRideChromeConstants.edgePadding)
                    .accessibilityIdentifier("dashboard.settings")
                }
            }
    }

    private var headerContentWidth: CGFloat? {
        headerColumnWidth.map { max(.zero, $0 - DashboardRideChromeConstants.edgePadding * 2) }
    }
}

private enum DashboardRideChromeConstants {
    static let edgePadding: CGFloat = 16
}
