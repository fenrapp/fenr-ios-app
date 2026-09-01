import DesignSystem
import SwiftUI

struct RideNavigationMetric: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.verticalSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraExtraSmall) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : Constants.minimumScaleFactor)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? nil : Constants.minimumWidth, alignment: .leading)
    }

    private enum Constants {
        static let verticalSpacing: CGFloat = 2
        static let minimumWidth: CGFloat = 76
        static let minimumScaleFactor = 0.7
    }
}
