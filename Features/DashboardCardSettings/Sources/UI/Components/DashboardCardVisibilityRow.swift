import DesignSystem
import SwiftUI

struct DashboardCardVisibilityRow<Label: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let isEnabled: Bool
    let disabledHint: String?
    @Binding var isVisible: Bool
    private let label: Label

    init(
        title: String,
        isEnabled: Bool,
        disabledHint: String?,
        isVisible: Binding<Bool>,
        @ViewBuilder label: () -> Label
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.disabledHint = disabledHint
        _isVisible = isVisible
        self.label = label()
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                    rowLabel

                    HStack {
                        Spacer(minLength: DesignSpace.extraSmall)
                        visibilityToggle
                    }
                }
            } else {
                HStack(spacing: DesignSpace.extraSmall) {
                    rowLabel
                    Spacer(minLength: DesignSpace.extraSmall)
                    visibilityToggle
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var rowLabel: some View {
        label
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var visibilityToggle: some View {
        DashboardCardVisibilityToggle(
            title: title,
            isEnabled: isEnabled,
            disabledHint: disabledHint,
            isVisible: $isVisible
        )
    }
}
