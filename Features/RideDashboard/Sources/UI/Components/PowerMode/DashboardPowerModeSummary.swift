import DesignSystem
import SwiftUI

struct DashboardPowerModeSummary: View {
    let state: DashboardPowerModeViewData

    @ViewBuilder
    var body: some View {
        if state.isVisible {
            HStack(spacing: DesignSpace.small) {
                metric(
                    value: state.horsepower,
                    unit: "HP",
                    accessibilityLabel: "Power"
                )
                separator
                metric(
                    value: state.regenerativeBraking,
                    unit: "%",
                    accessibilityLabel: "Regenerative braking"
                )

                if state.showsTractionControl {
                    separator
                    tractionControlMetric
                }
            }
            .padding(.horizontal, DesignSpace.medium)
            .frame(height: Constants.height)
            .background {
                Capsule()
                    .fill(DesignColor.groupedSurface)
            }
            .overlay {
                Capsule()
                    .stroke(DesignColor.border, lineWidth: Constants.outlineWidth)
            }
        }
    }

    private func metric(
        value: String,
        unit: String,
        accessibilityLabel: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraExtraSmall) {
            Text(value)
                .font(.system(size: Constants.valueFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(DesignColor.primaryText)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: Constants.unitFontSize, weight: .medium))
                .foregroundStyle(DesignColor.secondaryText)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(value) \(unit)")
    }

    private var tractionControlMetric: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraExtraSmall) {
            Text(state.powerTraction)
                .font(.system(size: Constants.valueFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(DesignColor.primaryText)
                .monospacedDigit()
            Text("%")
                .font(.system(size: Constants.unitFontSize, weight: .medium))
                .foregroundStyle(DesignColor.secondaryText)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Power traction control")
        .accessibilityValue("\(state.powerTraction) percent")
    }

    private var separator: some View {
        Rectangle()
            .fill(DesignColor.border)
            .frame(width: Constants.separatorWidth, height: Constants.separatorHeight)
            .accessibilityHidden(true)
    }

    private enum Constants {
        static let height: CGFloat = 48
        static let outlineWidth: CGFloat = 1.25
        static let separatorWidth: CGFloat = 1
        static let separatorHeight: CGFloat = 22
        static let valueFontSize: CGFloat = 24
        static let unitFontSize: CGFloat = 12
    }
}
