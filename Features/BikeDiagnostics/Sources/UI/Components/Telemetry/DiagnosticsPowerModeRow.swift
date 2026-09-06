import DesignSystem
import SwiftUI

struct DiagnosticsPowerModeRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let configuration: BikeDiagnosticsPowerModeViewData

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.rowSpacing) {
            HStack {
                Text(configuration.title)
                    .font(.headline)
                Spacer(minLength: DesignSpace.small)
                if configuration.isActive {
                    Label(DiagnosticsCopy.active, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, DesignSpace.extraSmall)
                        .padding(.vertical, DesignSpace.extraExtraSmall)
                        .background(.green.opacity(Constants.badgeOpacity), in: Capsule())
                }
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: Constants.rowSpacing) {
                ForEach(configuration.metrics) { metric in
                    VStack(alignment: .leading, spacing: Constants.metricSpacing) {
                        Text(metric.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(metric.value)
                            .font(.callout.weight(.semibold).monospacedDigit())
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, DesignSpace.extraExtraSmall)
        .accessibilityElement(children: .combine)
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: DesignSpace.small, alignment: .leading),
            count: dynamicTypeSize.isAccessibilitySize ? 2 : 4
        )
    }

    private enum Constants {
        static let rowSpacing: CGFloat = 10
        static let metricSpacing: CGFloat = 2
        static let badgeOpacity = 0.12
    }
}
