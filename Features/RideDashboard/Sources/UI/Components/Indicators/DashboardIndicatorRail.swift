import DesignSystem
import SwiftUI

struct DashboardIndicatorRail: View {
    let indicators: [DashboardIndicatorViewData]

    var body: some View {
        HStack(spacing: .zero) {
            ForEach(indicators) { indicator in
                if indicator.id != indicators.first?.id {
                    divider
                }
                indicatorView(indicator)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSpace.extraSmall)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignColor.border)
                .frame(height: 1)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignColor.border)
            .frame(width: 1, height: Constants.dividerHeight)
            .padding(.horizontal, Constants.dividerHorizontalPadding)
    }

    private func indicatorView(_ indicator: DashboardIndicatorViewData) -> some View {
        Image(systemName: indicator.symbolName)
            .font(.system(size: Constants.iconSize, weight: .semibold))
            .foregroundStyle(indicator.isActive ? tint(for: indicator.emphasis) : DesignColor.inactive)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(indicator.accessibilityLabel)
            .accessibilityValue(indicator.accessibilityValue)
    }

    private func tint(for emphasis: DashboardIndicatorEmphasis) -> Color {
        switch emphasis {
        case .informational: DesignColor.informational
        case .positive: DesignColor.positive
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }

    private enum Constants {
        static let dividerHeight: CGFloat = 22
        static let dividerHorizontalPadding: CGFloat = 14
        static let iconSize: CGFloat = 26.4
    }
}
