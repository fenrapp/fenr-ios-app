import DesignSystem
import SwiftUI

struct OnboardingMaterialPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            panelContent
                .glassEffect(in: panelShape)
                .overlay(panelBorder)
        } else {
            panelContent
                .background(surface)
                .overlay(panelBorder)
        }
    }

    private var panelContent: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSpace.medium)
    }

    private var surface: some View {
        panelShape.fill(.regularMaterial)
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Constants.panelRadius, style: .continuous)
    }

    private var panelBorder: some View {
        panelShape
            .stroke(DesignColor.border.opacity(Constants.borderOpacity), lineWidth: Constants.borderWidth)
    }
}

private enum Constants {
    static let panelRadius: CGFloat = 22
    static let borderOpacity = 0.7
    static let borderWidth: CGFloat = 1
}
