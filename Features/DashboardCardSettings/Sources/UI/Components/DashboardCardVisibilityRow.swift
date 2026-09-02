import DesignSystem
import Foundation
import SwiftUI

struct DashboardCardVisibilityRow<Label: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: LocalizedStringResource
    let isEnabled: Bool
    let disabledHint: LocalizedStringResource?
    @Binding var isVisible: Bool
    private let label: Label

    init(
        title: LocalizedStringResource,
        isEnabled: Bool,
        disabledHint: LocalizedStringResource?,
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
