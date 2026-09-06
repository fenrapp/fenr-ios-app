import SwiftUI

public struct ListActionLabel: View {
    private let title: String
    private let systemImage: String
    private let tint: Color
    private let isDestructive: Bool

    public init(
        title: String,
        systemImage: String,
        tint: Color = DesignColor.accent,
        isDestructive: Bool = false
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.isDestructive = isDestructive
    }

    public var body: some View {
        HStack(spacing: ListRowConstants.spacing) {
            ListRowIcon(systemImage: systemImage, tint: effectiveTint)

            Text(title)
                .foregroundStyle(isDestructive ? effectiveTint : Color.primary)

            Spacer(minLength: .zero)
        }
        .padding(.horizontal, DesignSpace.medium)
        .frame(
            maxWidth: .infinity,
            minHeight: ListRowConstants.minimumHeight,
            alignment: .leading
        )
        .contentShape(Rectangle())
    }

    private var effectiveTint: Color {
        isDestructive ? DesignColor.critical : tint
    }

}

#Preview("Action labels") {
    VStack(spacing: DesignSpace.small) {
        ListActionLabel(title: "Save changes", systemImage: "checkmark")
        ListActionLabel(title: "Delete item", systemImage: "trash", isDestructive: true)
    }
    .padding()
}
