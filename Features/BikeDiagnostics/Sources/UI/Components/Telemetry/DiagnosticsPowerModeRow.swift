import SwiftUI

struct DiagnosticsPowerModeRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let configuration: BikeDiagnosticsPowerModeViewData

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.rowSpacing) {
            HStack {
                Text(configuration.title)
                    .font(.headline)
                Spacer(minLength: Constants.spacing)
                if configuration.isActive {
                    Label(DiagnosticsCopy.active, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, Constants.badgeHorizontalPadding)
                        .padding(.vertical, Constants.badgeVerticalPadding)
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
        .padding(.vertical, Constants.verticalPadding)
        .accessibilityElement(children: .combine)
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: Constants.spacing, alignment: .leading),
            count: dynamicTypeSize.isAccessibilitySize ? 2 : 4
        )
    }

    private enum Constants {
        static let spacing: CGFloat = 12
        static let rowSpacing: CGFloat = 10
        static let metricSpacing: CGFloat = 2
        static let verticalPadding: CGFloat = 4
        static let badgeHorizontalPadding: CGFloat = 8
        static let badgeVerticalPadding: CGFloat = 4
        static let badgeOpacity = 0.12
    }
}
