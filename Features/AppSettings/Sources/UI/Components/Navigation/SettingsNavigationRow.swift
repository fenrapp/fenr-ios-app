#if os(iOS)
import DesignSystem
import Foundation
import SwiftUI

struct SettingsNavigationRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let icon: String
    let iconTint: Color
    let title: LocalizedStringResource
    let detail: Text
    let accessibilityIdentifier: String
    let action: () -> Void

    init(
        icon: String,
        iconTint: Color,
        title: LocalizedStringResource,
        detail: LocalizedStringResource,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconTint = iconTint
        self.title = title
        self.detail = Text(detail)
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    init(
        icon: String,
        iconTint: Color,
        title: LocalizedStringResource,
        verbatimDetail: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconTint = iconTint
        self.title = title
        self.detail = Text(verbatim: verbatimDetail)
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSpace.small) {
                SettingsRowIcon(systemName: icon, tint: iconTint)

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Constants.labelSpacing) {
                        titleLabel
                        detailLabel
                    }
                } else {
                    titleLabel
                    Spacer(minLength: DesignSpace.extraSmall)
                    detailLabel
                        .lineLimit(1)
                }

                if dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: DesignSpace.extraSmall)
                }

                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var titleLabel: some View {
        Text(title)
            .foregroundStyle(.primary)
    }

    private var detailLabel: some View {
        detail
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private enum Constants {
        static let labelSpacing: CGFloat = 2
    }
}
#endif
