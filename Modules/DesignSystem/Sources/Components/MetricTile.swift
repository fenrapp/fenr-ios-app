import SwiftUI

public struct MetricTile: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let title: String
    private let value: String

    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignColor.secondaryText)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .lineLimit(valueLineLimit)
                .minimumScaleFactor(valueMinimumScaleFactor)
        }
        .frame(maxWidth: .infinity, minHeight: Constants.minimumHeight, alignment: .leading)
        .padding(DesignSpace.small)
        .background(
            DesignColor.controlSurface,
            in: RoundedRectangle(cornerRadius: DesignRadius.small, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignRadius.small, style: .continuous)
                .stroke(DesignColor.border, lineWidth: Constants.borderWidth)
        )
        .accessibilityElement(children: .combine)
    }

    private var valueLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : Constants.valueLineLimit
    }

    private var valueMinimumScaleFactor: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 1 : Constants.minimumScaleFactor
    }

    private enum Constants {
        static let valueLineLimit = 1
        static let minimumScaleFactor = 0.7
        static let minimumHeight: CGFloat = 60
        static let borderWidth: CGFloat = 1
    }
}

private enum MetricTilePreviewConstants {
    static let width: CGFloat = 240
}

#Preview("Metric tile") {
    MetricTile(title: "Battery", value: "91%")
        .padding()
}

#Preview("Metric tile - long Dynamic Type") {
    MetricTile(
        title: "Estimated remaining range",
        value: "123.4 kilometers"
    )
    .frame(width: MetricTilePreviewConstants.width)
    .padding()
    .environment(\.dynamicTypeSize, .accessibility3)
}
