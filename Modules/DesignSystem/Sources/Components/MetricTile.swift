import SwiftUI

public struct MetricTile: View {
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
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .lineLimit(Constants.valueLineLimit)
                .minimumScaleFactor(Constants.minimumScaleFactor)
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
    }

    private enum Constants {
        static let valueLineLimit = 1
        static let minimumScaleFactor = 0.7
        static let minimumHeight: CGFloat = 60
        static let borderWidth: CGFloat = 1
    }
}

#Preview("Metric tile") {
    MetricTile(title: "Battery", value: "91%")
        .padding()
}
