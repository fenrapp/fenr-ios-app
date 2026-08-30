import DesignSystem
import SwiftUI

struct RideNavigationRow: View {
    let title: String
    let detail: String
    let image: String

    var body: some View {
        HStack(spacing: DesignSpace.small) {
            Image(systemName: image)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignColor.accent)
                .frame(width: Constants.iconWidth)
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DesignSpace.small)
        .frame(minHeight: Constants.rowHeight)
        .contentShape(Rectangle())
    }

    private enum Constants {
        static let iconWidth: CGFloat = 28
        static let rowHeight: CGFloat = 56
    }
}
