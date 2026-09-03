import SwiftUI

public struct ListNavigationRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let title: String
    private let subtitle: String
    private let systemImage: String
    private let tint: Color
    private let trailingValue: String?
    private let action: () -> Void

    public init(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        trailingValue: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.trailingValue = trailingValue
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: ListRowConstants.spacing) {
                ListRowIcon(systemImage: systemImage, tint: tint)

                VStack(alignment: .leading, spacing: Constants.textSpacing) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)

                if dynamicTypeSize.isAccessibilitySize, let trailingValue {
                    Text(trailingValue)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: dynamicTypeSize.isAccessibilitySize ? .zero : ListRowConstants.spacing)

                if !dynamicTypeSize.isAccessibilitySize, let trailingValue {
                    Text(trailingValue)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: ListRowConstants.minimumHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isLink)
    }

    private enum Constants {
        static let textSpacing: CGFloat = 2
    }
}
