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
        .listRowInsets(ListActionRowInsets.compact)
        .disabled(!isEnabled)
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackToken)
        .accessibilityElement(children: .combine)
    }

    private var effectiveTint: Color {
        isDestructive ? DesignColor.critical : tint
    }
}

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
        .frame(minHeight: ListRowConstants.minimumHeight)
        .contentShape(Rectangle())
    }

    private var effectiveTint: Color {
        isDestructive ? DesignColor.critical : tint
    }

}

public struct ListActionShareLink: View {
    @Environment(\.isEnabled) private var environmentIsEnabled
    @State private var feedbackToken = 0

    private let item: String
    private let title: String
    private let systemImage: String
    private let tint: Color
    private let isEnabled: Bool

    public init(
        item: String,
        title: String,
        systemImage: String,
        tint: Color = .indigo,
        isEnabled: Bool = true
    ) {
        self.item = item
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.isEnabled = isEnabled
    }

    public var body: some View {
        ShareLink(item: item) {
            ListActionLabel(title: title, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(ListActionRowButtonStyle(tint: tint))
        .listRowInsets(ListActionRowInsets.compact)
        .disabled(!isEnabled)
        .simultaneousGesture(TapGesture().onEnded {
            guard isEnabled, environmentIsEnabled else { return }
            feedbackToken += 1
        })
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackToken)
        .accessibilityElement(children: .combine)
    }
}

public struct ListActionRowButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    private let tint: Color

    public init(tint: Color = DesignColor.accent) {
        self.tint = tint
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? tint.opacity(Constants.pressedOpacity) : .clear,
                in: RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
            )
            .opacity(contentOpacity(isPressed: configuration.isPressed))
            .animation(.easeOut(duration: Constants.animationDuration), value: configuration.isPressed)
            .animation(.easeOut(duration: Constants.animationDuration), value: isEnabled)
    }

    private func contentOpacity(isPressed: Bool) -> Double {
        guard isEnabled else { return Constants.disabledContentOpacity }
        return isPressed ? Constants.pressedContentOpacity : 1
    }

    private enum Constants {
        static let pressedOpacity = 0.12
        static let pressedContentOpacity = 0.82
        static let disabledContentOpacity = 0.45
        static let cornerRadius = DesignSpace.extraSmall
        static let animationDuration = 0.12
    }
}

public enum ListActionRowInsets {
    public static let compact = EdgeInsets(
        top: .zero,
        leading: DesignSpace.medium,
        bottom: .zero,
        trailing: DesignSpace.medium
    )
}
