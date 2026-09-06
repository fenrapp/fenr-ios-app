import SwiftUI

public struct ListActionButton: View {
    @State private var feedbackToken = 0

    private let title: String
    private let systemImage: String
    private let tint: Color
    private let isEnabled: Bool
    private let isDestructive: Bool
    private let action: () -> Void

    public init(
        title: String,
        systemImage: String,
        tint: Color = DesignColor.accent,
        isEnabled: Bool = true,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.isEnabled = isEnabled
        self.isDestructive = isDestructive
        self.action = action
    }

    public var body: some View {
        Button(role: isDestructive ? .destructive : nil) {
            feedbackToken += 1
            action()
        } label: {
            ListActionLabel(
                title: title,
                systemImage: systemImage,
                tint: tint,
                isDestructive: isDestructive
            )
        }
        .buttonStyle(ListActionRowButtonStyle(tint: effectiveTint))
        .listRowInsets(ListRowConstants.actionInsets)
        .disabled(!isEnabled)
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackToken)
        .accessibilityElement(children: .combine)
    }

    private var effectiveTint: Color {
        isDestructive ? DesignColor.critical : tint
    }
}

#Preview("Action buttons") {
    List {
        ListActionButton(title: "Save changes", systemImage: "checkmark") {}
        ListActionButton(title: "Delete item", systemImage: "trash", isDestructive: true) {}
        ListActionButton(title: "Unavailable", systemImage: "lock", isEnabled: false) {}
    }
}
