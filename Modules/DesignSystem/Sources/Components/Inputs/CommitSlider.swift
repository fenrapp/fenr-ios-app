import SwiftUI

public struct CommitSlider<Header: View, Footer: View>: View {
    @Environment(\.isEnabled) private var environmentIsEnabled

    private let value: Double
    private let bounds: ClosedRange<Double>
    private let step: Double
    private let rendering: CommitSliderRendering
    private let isEnabled: Bool
    private let accessibilityLabel: String?
    private let accessibilityValue: (Double) -> String
    private let onCommit: (Double) -> Void
    private let header: (Double) -> Header
    private let footer: Footer

    @State private var interaction: CommitSliderInteractionState
    @State private var commitFeedbackToken = 0

    public init(
        value: Double,
        in bounds: ClosedRange<Double>,
        step: Double,
        tint: Color = DesignColor.accent,
        isEnabled: Bool = true,
        onCommit: @escaping (Double) -> Void,
        @ViewBuilder header: @escaping (Double) -> Header,
        @ViewBuilder footer: () -> Footer
    ) {
        self.value = value
        self.bounds = bounds
        self.step = step
        rendering = .system(tint)
        self.isEnabled = isEnabled
        accessibilityLabel = nil
        accessibilityValue = { $0.formatted() }
        self.onCommit = onCommit
        self.header = header
        self.footer = footer()
        _interaction = State(initialValue: CommitSliderInteractionState(value: value, bounds: bounds))
    }

    public init(
        value: Double,
        in bounds: ClosedRange<Double>,
        step: Double,
        appearance: CommitSliderAppearance,
        isEnabled: Bool = true,
        accessibilityLabel: String? = nil,
        accessibilityValue: @escaping (Double) -> String = { $0.formatted() },
        onCommit: @escaping (Double) -> Void,
        @ViewBuilder header: @escaping (Double) -> Header,
        @ViewBuilder footer: () -> Footer
    ) {
        self.value = value
        self.bounds = bounds
        self.step = step
        rendering = .gradient(appearance)
        self.isEnabled = isEnabled
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
        self.onCommit = onCommit
        self.header = header
        self.footer = footer()
        _interaction = State(initialValue: CommitSliderInteractionState(value: value, bounds: bounds))
    }

    public var body: some View {
        VStack(spacing: DesignSpace.extraExtraSmall) {
            header(interaction.displayedValue)
            control
            footer
        }
        .sensoryFeedback(.selection, trigger: commitFeedbackToken)
        .onChange(of: value) { _, newValue in
            interaction.synchronize(externalValue: newValue, bounds: bounds)
        }
        .onChange(of: bounds.lowerBound) { synchronizeBounds() }
        .onChange(of: bounds.upperBound) { synchronizeBounds() }
        .onChange(of: effectiveIsEnabled) { _, enabled in
            guard !enabled else { return }
            interaction.cancelEditing(externalValue: value, bounds: bounds)
        }
    }

    @ViewBuilder
    private var control: some View {
        switch rendering {
        case let .system(tint):
            Slider(
                value: displayedValue,
                in: bounds,
                step: CommitSliderValueMath.validStep(step),
                onEditingChanged: editingChanged
            )
            .tint(tint)
            .frame(minHeight: CommitSliderConstants.minimumControlHeight)
            .disabled(!effectiveIsEnabled)
        case let .gradient(appearance):
            GradientCommitSliderControl(
                externalValue: value,
                bounds: bounds,
                step: step,
                appearance: appearance,
                isEnabled: effectiveIsEnabled,
                accessibilityLabel: accessibilityLabel,
                accessibilityValue: accessibilityValue(interaction.displayedValue),
                interaction: $interaction,
                onCommit: { committedValue in
                    if appearance.providesCommitFeedback {
                        commitFeedbackToken += 1
                    }
                    onCommit(committedValue)
                }
            )
        }
    }

    private var displayedValue: Binding<Double> {
        Binding(
            get: { interaction.displayedValue },
            set: {
                interaction.updateDisplayedValue(
                    $0,
                    bounds: bounds,
                    isEnabled: effectiveIsEnabled
                )
            }
        )
    }

    private func editingChanged(_ isEditing: Bool) {
        if isEditing {
            interaction.beginEditing(isEnabled: effectiveIsEnabled)
        } else if let committedValue = interaction.finishEditing(
            externalValue: value,
            bounds: bounds,
            isEnabled: effectiveIsEnabled
        ) {
            onCommit(committedValue)
        }
    }

    private func synchronizeBounds() {
        interaction.synchronize(externalValue: value, bounds: bounds)
    }

    private var effectiveIsEnabled: Bool {
        isEnabled && environmentIsEnabled
    }
}

private enum CommitSliderRendering {
    case system(Color)
    case gradient(CommitSliderAppearance)
}

#Preview("Commit slider") {
    CommitSlider(
        value: 65,
        in: 20 ... 100,
        step: 5,
        tint: DesignColor.positive,
        onCommit: { _ in },
        header: { value in
            Text(verbatim: "Charge target \(value.formatted())%")
        },
        footer: {
            Text(verbatim: "20% - 100%")
                .font(.caption)
        }
    )
    .padding()
}
