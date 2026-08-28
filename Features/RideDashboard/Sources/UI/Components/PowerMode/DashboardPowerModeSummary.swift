import DesignSystem
import SwiftUI

struct DashboardPowerModeSummary: View {
    enum Layout {
        case horizontal
        case sidebar
    }

    let state: DashboardPowerModeViewData
    let layout: Layout

    init(
        state: DashboardPowerModeViewData,
        layout: Layout = .horizontal
    ) {
        self.state = state
        self.layout = layout
    }

    @ViewBuilder
    var body: some View {
        if state.isVisible {
            switch layout {
            case .horizontal:
                horizontalContent
                    .frame(height: Constants.height)
                    .dashboardPowerModeSurface()
            case .sidebar:
                ViewThatFits(in: .horizontal) {
                    sidebarHorizontalContent
                        .frame(height: Constants.height)
                        .dashboardPowerModeSurface()
                    sidebarContent
                        .padding(.vertical, DesignSpace.small)
                        .dashboardPowerModeSurface()
                }
            }
        }
    }

    private var horizontalContent: some View {
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
        .fixedSize(horizontal: true, vertical: false)
    }

    private var sidebarContent: some View {
        VStack(spacing: DesignSpace.extraSmall) {
            powerMetric
            regenerationMetric
        }
        .padding(.horizontal, DesignSpace.small)
        .frame(maxWidth: .infinity)
    }

    private var sidebarHorizontalContent: some View {
        HStack(spacing: DesignSpace.small) {
            powerMetric
            separator
            regenerationMetric
        }
        .padding(.horizontal, DesignSpace.small)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var powerMetric: some View {
        metric(
            value: state.horsepower,
            unit: "HP",
            accessibilityLabel: "Power"
        )
    }

    private var regenerationMetric: some View {
        metric(
            value: state.regenerativeBraking,
            unit: "%",
            accessibilityLabel: "Regenerative braking"
        )
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
        static let separatorWidth: CGFloat = 1
        static let separatorHeight: CGFloat = 22
        static let valueFontSize: CGFloat = 24
        static let unitFontSize: CGFloat = 12
    }
}

private extension View {
    func dashboardPowerModeSurface() -> some View {
        background {
            Capsule()
                .fill(DesignColor.groupedSurface)
        }
        .overlay {
            Capsule()
                .stroke(DesignColor.border, lineWidth: DashboardPowerModeSurfaceConstants.outlineWidth)
        }
    }
}

private enum DashboardPowerModeSurfaceConstants {
    static let outlineWidth: CGFloat = 1.25
}
