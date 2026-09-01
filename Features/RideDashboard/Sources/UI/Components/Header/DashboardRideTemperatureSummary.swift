import DesignSystem
import SwiftUI

struct DashboardRideTemperatureSummary: View {
    let state: RideDashboardViewState.TemperatureSummary

    var body: some View {
        DashboardTemperatureCapsule {
            HStack(spacing: Constants.itemSpacing) {
                if let batteryTemperatureText = state.batteryTemperatureText {
                    DashboardTemperatureItem(
                        text: batteryTemperatureText,
                        systemImage: "battery.100percent",
                        accessibilityLabel: "Battery temperature"
                    )
                }

                if state.batteryTemperatureText != nil, state.inverterTemperatureText != nil {
                    Divider()
                        .frame(height: Constants.separatorHeight)
                }

                if let inverterTemperatureText = state.inverterTemperatureText {
                    DashboardTemperatureItem(
                        text: inverterTemperatureText,
                        systemImage: "bolt.horizontal.fill",
                        accessibilityLabel: "Inverter temperature"
                    )
                }
            }
        }
    }

    private enum Constants {
        static let itemSpacing: CGFloat = 5
        static let separatorHeight: CGFloat = 13
    }
}

private struct DashboardTemperatureItem: View {
    let text: String
    let systemImage: String
    let accessibilityLabel: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(text)
    }
}

private struct DashboardTemperatureCapsule<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .font(.system(
                size: DashboardTemperatureCapsuleConstants.valueFontSize,
                weight: .semibold,
                design: .rounded
            ))
            .foregroundStyle(DesignColor.primaryText)
            .monospacedDigit()
            .padding(.horizontal, DashboardTemperatureCapsuleConstants.horizontalPadding)
            .frame(height: DashboardTemperatureCapsuleConstants.height)
            .background {
                Capsule()
                    .fill(DesignColor.groupedSurface)
            }
            .overlay {
                Capsule()
                    .stroke(DesignColor.border, lineWidth: DashboardTemperatureCapsuleConstants.outlineWidth)
            }
    }
}

private enum DashboardTemperatureCapsuleConstants {
    static let height: CGFloat = 29
    static let horizontalPadding: CGFloat = 10
    static let outlineWidth: CGFloat = 1.25
    static let valueFontSize: CGFloat = 14
}

extension RideDashboardViewState.TemperatureSummary {
    var hasValues: Bool {
        batteryTemperatureText != nil || inverterTemperatureText != nil
    }
}
