import DesignSystem
import SwiftUI

struct RideHistorySummaryMetric: View {
    let label: LocalizedStringResource
    let symbolName: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
            Image(systemName: symbolName)
                .font(.caption)
                .foregroundStyle(DesignColor.accent)
                .accessibilityHidden(true)
            Text(verbatim: value)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DesignColor.primaryText)
            Text(label)
                .font(.caption2)
                .foregroundStyle(DesignColor.secondaryText)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}
