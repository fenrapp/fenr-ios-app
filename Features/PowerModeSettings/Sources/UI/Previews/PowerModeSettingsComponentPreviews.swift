import SwiftUI

#Preview("Controls") {
    List {
        Section("Performance") {
            PowerModeAdjustmentRow(
                state: previewAdjustment(id: .power, value: 58),
                commit: { _ in }
            )
            PowerModeAdjustmentRow(
                state: previewAdjustment(id: .regeneration, value: 42),
                commit: { _ in }
            )
        }

        Section("Traction") {
            PowerModeAdjustmentRow(
                state: previewAdjustment(
                    id: .powerTraction,
                    value: 65,
                    feedback: .init(
                        state: .confirmed,
                        title: "Confirmed",
                        systemImage: "checkmark.circle.fill",
                        emphasis: .positive
                    )
                ),
                commit: { _ in }
            )
        }
    }
}

#Preview("Status and selector · Accessibility XXXL") {
    List {
        PowerModeStatusPanel(
            status: .init(
                title: "Controls unavailable",
                detail: "Unable to apply traction control. Try again.",
                systemImage: "exclamationmark.triangle.fill",
                emphasis: .critical,
                isActivity: false
            ),
            canRetry: true,
            retry: {}
        )
        PowerModeSelector(
            maps: previewMaps,
            select: { _ in }
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Edit map name") {
    PowerModeNameEditor(
        mapIndex: 0,
        currentName: "Enduro",
        maximumLength: 10,
        isEnabled: true,
        error: "Use a unique name for each map.",
        save: { _ in false },
        reset: {}
    )
}

private var previewMaps: [PowerModeMapViewData] {
    (0 ... 4).map { index in
        .init(
            id: index,
            title: index == 0 ? "Enduro" : "\(index + 1)",
            accessibilityLabel: index == 0 ? "Map 1, Enduro" : "Map \(index + 1)",
            isSelected: index == 0
        )
    }
}

private func previewAdjustment(
    id: PowerModeAdjustmentID,
    value: Double,
    feedback: PowerModeControlFeedback = .idle
) -> PowerModeAdjustmentViewState {
    let isPower = id == .power
    return .init(
        id: id,
        title: previewTitle(for: id),
        value: value,
        valueText: value.formatted(),
        unit: isPower ? "HP" : "%",
        minimum: isPower ? 10 : 0,
        maximum: isPower ? 80 : 100,
        step: 1,
        isEnabled: true,
        localeIdentifier: "en_US",
        feedback: feedback
    )
}

private func previewTitle(for id: PowerModeAdjustmentID) -> String {
    switch id {
    case .power: "Power"
    case .regeneration: "Regenerative braking"
    case .powerTraction: "Traction control"
    case .brakingTraction: "Regen traction control"
    }
}

#Preview("Control feedback states") {
    List {
        PowerModeControlFeedbackView(feedback: .init(
            state: .applying, title: "Applying setting", emphasis: .informational, isActivity: true
        ))
        PowerModeControlFeedbackView(feedback: .init(
            state: .confirmed, title: "Confirmed", systemImage: "checkmark.circle.fill", emphasis: .positive
        ))
        PowerModeControlFeedbackView(feedback: .init(
            state: .failed,
            title: "The bike did not confirm the change. Try again.",
            systemImage: "exclamationmark.triangle.fill",
            emphasis: .critical
        ))
    }
}
