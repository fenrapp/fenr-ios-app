import SwiftUI

public struct ListRowIcon: View {
    private let systemImage: String
    private let tint: Color

    public init(systemImage: String, tint: Color) {
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
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

#Preview("Row icons") {
    HStack(spacing: DesignSpace.small) {
        ListRowIcon(systemImage: "checkmark", tint: DesignColor.positive)
        ListRowIcon(systemImage: "exclamationmark.triangle", tint: DesignColor.warning)
        ListRowIcon(systemImage: "trash", tint: DesignColor.critical)
    }
    .padding()
}
