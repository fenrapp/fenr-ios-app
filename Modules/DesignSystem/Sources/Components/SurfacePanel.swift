import SwiftUI

public struct SurfacePanel<Content: View>: View {
    private let title: String
    private let content: Content

    public init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignColor.secondaryText)
                .textCase(.uppercase)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSpace.small)
        .background(
            RoundedRectangle(cornerRadius: DesignRadius.small, style: .continuous)
                .fill(DesignColor.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignRadius.small, style: .continuous)
                .stroke(DesignColor.border, lineWidth: SurfacePanelConstants.borderWidth)
        )
    }
}

private enum SurfacePanelConstants {
    static let borderWidth: CGFloat = 1
    static let previewWidth: CGFloat = 280
}

#Preview("Surface panel") {
    SurfacePanel(title: "Summary") {
        Text("76%")
            .font(.title3.bold())
    }
    .padding()
}

#Preview("Surface panel - multiline content") {
    SurfacePanel(title: "Battery health and charging summary") {
        Text("Battery temperature is within the recommended operating range.")
        Text("Last updated a few moments ago")
            .foregroundStyle(DesignColor.secondaryText)
    }
    .frame(width: SurfacePanelConstants.previewWidth)
    .padding()
    .environment(\.dynamicTypeSize, .accessibility3)
}
