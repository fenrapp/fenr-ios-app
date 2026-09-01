import DesignSystem
import SwiftUI

struct RideHistoryComparisonRow: View {
    let comparison: RideHistoryDetailViewState.Comparison

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Constants.accessibilitySpacing) {
                    comparisonLabel
                    comparisonValue
                        .padding(.leading, Constants.iconWidth + Constants.spacing)
                }
            } else {
                HStack(spacing: Constants.spacing) {
                    comparisonLabel
                    Spacer(minLength: Constants.minimumSpacing)
                    comparisonValue
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var comparisonLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: Constants.spacing) {
            Image(systemName: symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(emphasisColor)
                .frame(width: Constants.iconWidth)

            VStack(alignment: .leading, spacing: Constants.textSpacing) {
                Text(comparison.label)
                    .font(.body)
                Text(comparison.detail)
                    .font(.caption)
                    .foregroundStyle(DesignColor.secondaryText)
            }
        }
    }

    private var comparisonValue: some View {
        Text(comparison.value)
            .font(.body.weight(.semibold))
            .foregroundStyle(emphasisColor)
            .monospacedDigit()
    }

    private var symbolName: String {
        switch comparison.emphasis {
        case .neutral: "arrow.left.and.right"
        case .positive: "arrow.up.right"
        case .negative: "arrow.down.right"
        }
    }

    private var emphasisColor: Color {
        switch comparison.emphasis {
        case .neutral: DesignColor.secondaryText
        case .positive: DesignColor.positive
        case .negative: DesignColor.warning
        }
    }

    private enum Constants {
        static let iconWidth: CGFloat = 24
        static let spacing: CGFloat = 10
        static let textSpacing: CGFloat = 2
        static let minimumSpacing: CGFloat = 8
        static let accessibilitySpacing: CGFloat = 6
    }
}
