import DesignSystem
import SwiftUI

public struct BikeDemoAccessButton: View {
    private let onOpen: () -> Void

    public init(onOpen: @escaping () -> Void) {
        self.onOpen = onOpen
    }

    public var body: some View {
        Button(action: onOpen) {
            Label(.bikeDemoBadge, systemImage: "play.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(DesignColor.warning)
        .accessibilityLabel(.bikeDemoOpenControls)
        .accessibilityIdentifier("demo.openControls")
    }
}
