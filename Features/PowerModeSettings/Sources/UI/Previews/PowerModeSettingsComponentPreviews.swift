import SwiftUI

#Preview("Adjustment · Ready") {
    Form {
        PowerModeAdjustmentRow(
            state: previewAdjustment(isEnabled: true),
            commit: { _ in }
        )
    }
}

#Preview("Adjustment · Accessibility XXXL") {
    Form {
        PowerModeAdjustmentRow(
            state: previewAdjustment(isEnabled: false),
            commit: { _ in }
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Name and status · Accessibility XXXL") {
    Form {
        PowerModeStatusPanel(
            connectionText: "Bike connected",
            capabilityText: "Alpha capability detected · 80 HP",
            statusText: "Unable to apply traction control",
            statusIsError: true
        )
        PowerModeNameEditor(
            mapIndex: 0,
            currentName: "Enduro",
            maximumLength: 10,
            isEnabled: true,
            error: "Use a unique name for each map.",
            save: { _ in },
            reset: {}
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

private func previewAdjustment(isEnabled: Bool) -> PowerModeAdjustmentViewState {
    .init(
        id: .regeneration,
        title: "Regenerative braking",
        value: -42,
        valueText: "-42",
        unit: "%",
        minimum: -100,
        maximum: 100,
        step: 1,
        isEnabled: isEnabled,
        localeIdentifier: "en_US"
    )
}
