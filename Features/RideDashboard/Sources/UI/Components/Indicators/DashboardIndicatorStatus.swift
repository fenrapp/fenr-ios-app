import DesignSystem
import SwiftUI

struct DashboardIndicatorStatus: View {
    let indicators: [DashboardIndicatorViewData]

    var body: some View {
        HStack(spacing: DesignSpace.extraSmall) {
            ForEach(activeIndicators) { indicator in
                indicatorChip(indicator)
                    .transition(.scale(scale: Constants.transitionScale).combined(with: .opacity))
            }
        }
        .frame(height: Constants.diameter)
        .accessibilityHidden(activeIndicators.isEmpty)
        .animation(Constants.stateAnimation, value: activeIndicators)
    }

    private func indicatorChip(_ indicator: DashboardIndicatorViewData) -> some View {
        let tint = tint(for: indicator.emphasis)
        return Image(systemName: indicator.symbolName)
            .font(.system(size: Constants.iconFontSize, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: Constants.diameter, height: Constants.diameter)
            .background {
                Circle()
                    .fill(tint.opacity(Constants.backgroundOpacity))
            }
            .overlay {
                Circle()
                    .stroke(tint, lineWidth: Constants.outlineWidth)
            }
            .accessibilityLabel(indicator.accessibilityLabel)
            .accessibilityValue(indicator.accessibilityValue)
    }

    private var activeIndicators: [DashboardIndicatorViewData] {
        indicators.filter(Self.isDisplayed)
    }

    nonisolated static func hasActiveIndicators(_ indicators: [DashboardIndicatorViewData]) -> Bool {
        indicators.contains(where: Self.isDisplayed)
    }

    nonisolated private static func isDisplayed(_ indicator: DashboardIndicatorViewData) -> Bool {
        indicator.isActive && IndicatorID(rawValue: indicator.id) != nil
    }

    private func tint(for emphasis: DashboardIndicatorEmphasis) -> Color {
        switch emphasis {
        case .informational: DesignColor.informational
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }

    nonisolated private enum IndicatorID: String {
        case highBeam
        case leftTurn
        case rightTurn
    }

    private enum Constants {
        static let diameter: CGFloat = 60
        static let outlineWidth: CGFloat = 2.75
        static let backgroundOpacity = 0.08
        static let iconFontSize: CGFloat = 26
        static let transitionScale = 0.86
        static let stateAnimation = Animation.easeInOut(duration: 0.14)
    }
}
