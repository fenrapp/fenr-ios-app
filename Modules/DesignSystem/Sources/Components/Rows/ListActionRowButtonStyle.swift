import SwiftUI

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
        static let cornerRadius = DesignRadius.small
        static let animationDuration = 0.12
    }
}

#Preview("Action row button style") {
    Button {} label: {
        ListActionLabel(title: "Action", systemImage: "checkmark")
    }
    .buttonStyle(ListActionRowButtonStyle())
    .padding()
}
