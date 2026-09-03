import SwiftUI

struct ListRowIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: ListRowConstants.iconGlyphSize, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: ListRowConstants.iconSize, height: ListRowConstants.iconSize)
            .background(tint.opacity(ListRowConstants.iconBackgroundOpacity), in: iconBackground)
            .accessibilityHidden(true)
    }

    private var iconBackground: RoundedRectangle {
        RoundedRectangle(cornerRadius: ListRowConstants.iconRadius, style: .continuous)
    }
}

enum ListRowConstants {
    static let spacing = DesignSpace.small
    static let iconSize = DesignSpace.extraLarge
    static let iconGlyphSize: CGFloat = 16
    static let iconRadius = DesignSpace.extraSmall
    static let iconBackgroundOpacity = 0.12
    static let minimumHeight: CGFloat = 44
}
