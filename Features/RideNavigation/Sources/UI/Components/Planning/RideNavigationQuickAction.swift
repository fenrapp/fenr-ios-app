import DesignSystem
import SwiftUI

struct RideNavigationQuickAction: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DesignSpace.small)
            .frame(maxWidth: .infinity, minHeight: Constants.minimumHeight, alignment: .leading)
            .background(DesignColor.groupedSurface, in: RoundedRectangle(cornerRadius: DesignRadius.medium))
            .contentShape(RoundedRectangle(cornerRadius: DesignRadius.medium))
        }
        .buttonStyle(.plain)
    }

    private enum Constants {
        static let minimumHeight: CGFloat = 82
    }
}
