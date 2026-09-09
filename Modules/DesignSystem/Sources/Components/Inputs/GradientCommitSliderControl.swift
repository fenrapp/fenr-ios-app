import SwiftUI

struct GradientCommitSliderControl: View {
    let externalValue: Double
    let bounds: ClosedRange<Double>
    let step: Double
    let appearance: CommitSliderAppearance
    let isEnabled: Bool
    let allowsUnchangedCommit: Bool
    let accessibilityLabel: String?
    let accessibilityValue: String
    @Binding var interaction: CommitSliderInteractionState
    let onDoubleTap: (() -> Void)?
    let onCommit: (Double) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.isEnabled) private var environmentIsEnabled
    @ScaledMetric(relativeTo: .body) private var trackHeight = CommitSliderConstants.trackHeight
    @ScaledMetric(relativeTo: .body) private var thumbDiameter = CommitSliderConstants.thumbDiameter
    @State private var dragIntent = CommitSliderDragIntent.undecided

    var body: some View {
        GeometryReader { proxy in
            let layout = CommitSliderLayout(
                bounds: bounds,
                width: proxy.size.width,
                thumbDiameter: thumbDiameter
            )

            ZStack(alignment: .leading) {
                backgroundTrack(layout: layout)
                progressTrack(layout: layout)
                centerMarker(layout: layout)
                thumbHalo(layout: layout)
                thumb(layout: layout)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .simultaneousGesture(dragGesture(layout: layout))
            .simultaneousGesture(tapGesture(layout: layout))
        }
        .frame(minHeight: minimumControlHeight)
        .opacity(effectiveIsEnabled ? 1 : CommitSliderConstants.disabledOpacity)
        .disabled(!isEnabled)
        .animation(
            reduceMotion ? nil : .snappy(duration: CommitSliderConstants.animationDuration),
            value: interaction.isEditing
        )
        .accessibilityElement(children: .ignore)
        .modifier(
            CommitSliderAccessibilityModifier(
                label: accessibilityLabel,
                value: accessibilityValue,
                isEnabled: effectiveIsEnabled,
                adjustment: adjustAccessibilityValue
            )
        )
        .onChange(of: effectiveIsEnabled) { _, enabled in
            guard !enabled else { return }
            dragIntent = .undecided
            interaction.cancelEditing(externalValue: externalValue, bounds: bounds)
        }
    }

    private func backgroundTrack(layout: CommitSliderLayout) -> some View {
        Capsule()
            .fill(backgroundTrackColor)
            .overlay {
                if colorSchemeContrast == .increased {
                    Capsule()
                        .strokeBorder(
                            DesignColor.primaryText,
                            lineWidth: CommitSliderConstants.highContrastStrokeWidth
                        )
                }
            }
            .frame(width: layout.trackWidth, height: trackHeight)
            .offset(x: layout.trackOrigin)
    }

    private func progressTrack(layout: CommitSliderLayout) -> some View {
        sliderGradient(startPoint: .leading, endPoint: .trailing)
            .frame(width: layout.trackWidth, height: trackHeight)
            .mask(alignment: .leading) {
                Capsule()
                    .frame(
                        width: layout.progressWidth(for: interaction.displayedValue),
                        height: trackHeight
                    )
            }
            .offset(x: layout.trackOrigin)
    }

    @ViewBuilder
    private func centerMarker(layout: CommitSliderLayout) -> some View {
        if appearance.showsCenterMarker {
            Capsule()
                .fill(DesignColor.primaryText.opacity(centerMarkerOpacity))
                .frame(
                    width: CommitSliderConstants.centerMarkerWidth,
                    height: trackHeight + CommitSliderConstants.centerMarkerOverhang
                )
                .offset(x: layout.centerPosition - CommitSliderConstants.centerMarkerWidth / 2)
                .accessibilityHidden(true)
        }
    }

    private func thumbHalo(layout: CommitSliderLayout) -> some View {
        Circle()
            .fill(sliderGradient(startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(
                width: thumbDiameter + CommitSliderConstants.haloExpansion,
                height: thumbDiameter + CommitSliderConstants.haloExpansion
            )
            .opacity(interaction.isEditing ? CommitSliderConstants.haloOpacity : .zero)
            .blur(radius: CommitSliderConstants.haloBlurRadius)
            .offset(
                x: layout.thumbOrigin(for: interaction.displayedValue)
                    - CommitSliderConstants.haloExpansion / 2
            )
            .accessibilityHidden(true)
    }

    private func thumb(layout: CommitSliderLayout) -> some View {
        Circle()
            .fill(appearance.thumbColor)
            .overlay { thumbStroke }
            .shadow(
                color: DesignColor.primaryText.opacity(CommitSliderConstants.thumbShadowOpacity),
                radius: CommitSliderConstants.thumbShadowRadius,
                y: CommitSliderConstants.thumbShadowOffset
            )
            .frame(width: thumbDiameter, height: thumbDiameter)
            .scaleEffect(interaction.isEditing ? CommitSliderConstants.editingScale : 1)
            .offset(x: layout.thumbOrigin(for: interaction.displayedValue))
            .accessibilityHidden(true)
    }

    private func sliderGradient(startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient {
        LinearGradient(stops: resolvedStops, startPoint: startPoint, endPoint: endPoint)
    }

    private var resolvedStops: [Gradient.Stop] {
        guard !appearance.gradientStops.isEmpty else {
            return [
                .init(color: DesignColor.accent, location: .zero),
                .init(color: DesignColor.accent, location: 1)
            ]
        }
        return appearance.gradientStops
    }

    private var backgroundTrackOpacity: Double {
        colorSchemeContrast == .increased
            ? CommitSliderConstants.highContrastBackgroundTrackOpacity
            : CommitSliderConstants.backgroundTrackOpacity
    }

    private var backgroundTrackColor: Color {
        if colorSchemeContrast == .increased {
            return DesignColor.primaryText.opacity(backgroundTrackOpacity)
        }
        return DesignColor.inactive
    }

    private var centerMarkerOpacity: Double {
        colorSchemeContrast == .increased
            ? CommitSliderConstants.highContrastCenterMarkerOpacity
            : CommitSliderConstants.centerMarkerOpacity
    }

    private var thumbStrokeWidth: CGFloat {
        colorSchemeContrast == .increased
            ? CommitSliderConstants.highContrastStrokeWidth
            : CommitSliderConstants.strokeWidth
    }

    private var minimumControlHeight: CGFloat {
        max(CommitSliderConstants.minimumControlHeight, thumbDiameter + CommitSliderConstants.haloExpansion)
    }

    @ViewBuilder private var thumbStroke: some View {
        if colorSchemeContrast == .increased {
            Circle()
                .strokeBorder(DesignColor.primaryText, lineWidth: thumbStrokeWidth)
        } else {
            Circle()
                .strokeBorder(
                    sliderGradient(startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: thumbStrokeWidth
                )
        }
    }

    private var effectiveIsEnabled: Bool {
        isEnabled && environmentIsEnabled
    }

    private func dragGesture(layout: CommitSliderLayout) -> some Gesture {
        DragGesture(minimumDistance: CommitSliderConstants.dragIntentThreshold)
            .onChanged { gesture in
                guard effectiveIsEnabled else { return }
                if dragIntent == .undecided {
                    dragIntent = CommitSliderDragIntent.resolve(translation: gesture.translation)
                }
                guard dragIntent == .horizontal else { return }
                interaction.beginEditing(isEnabled: effectiveIsEnabled)
                interaction.updateDisplayedValue(
                    layout.value(at: gesture.location.x, step: step),
                    bounds: bounds,
                    isEnabled: effectiveIsEnabled
                )
            }
            .onEnded { _ in
                defer { dragIntent = .undecided }
                guard dragIntent == .horizontal else { return }
                finishEditing()
            }
    }

    private func tapGesture(layout: CommitSliderLayout) -> AnyGesture<Void> {
        if let onDoubleTap {
            return AnyGesture(
                SpatialTapGesture(count: 2)
                    .exclusively(before: SpatialTapGesture())
                    .onEnded { gesture in
                        guard effectiveIsEnabled else { return }
                        switch gesture {
                        case .first: onDoubleTap()
                        case .second(let tap): selectValue(at: tap.location.x, layout: layout)
                        }
                    }
                    .map { _ in () }
            )
        }
        return AnyGesture(
            SpatialTapGesture()
                .onEnded { selectValue(at: $0.location.x, layout: layout) }
                .map { _ in () }
        )
    }

    private func selectValue(at position: CGFloat, layout: CommitSliderLayout) {
        guard effectiveIsEnabled else { return }
        let tappedValue = layout.value(at: position, step: step)
        guard allowsUnchangedCommit || tappedValue != interaction.displayedValue else { return }
        interaction.beginEditing(isEnabled: effectiveIsEnabled)
        interaction.updateDisplayedValue(tappedValue, bounds: bounds, isEnabled: effectiveIsEnabled)
        finishEditing()
    }

    private func adjustAccessibilityValue(_ direction: AccessibilityAdjustmentDirection) {
        guard effectiveIsEnabled else { return }
        let adjustedValue = CommitSliderValueMath.adjustedValue(
            interaction.displayedValue,
            direction: direction,
            bounds: bounds,
            step: step
        )
        interaction.beginEditing(isEnabled: effectiveIsEnabled)
        interaction.updateDisplayedValue(adjustedValue, bounds: bounds, isEnabled: effectiveIsEnabled)
        finishEditing()
    }

    private func finishEditing() {
        guard let committedValue = interaction.finishEditing(
            externalValue: externalValue,
            bounds: bounds,
            isEnabled: effectiveIsEnabled,
            allowsUnchangedCommit: allowsUnchangedCommit
        ) else { return }
        onCommit(committedValue)
    }
}

private struct CommitSliderAccessibilityModifier: ViewModifier {
    let label: String?
    let value: String
    let isEnabled: Bool
    let adjustment: (AccessibilityAdjustmentDirection) -> Void

    func body(content: Content) -> some View {
        if let label {
            accessibleContent(content.accessibilityLabel(Text(verbatim: label)))
        } else {
            accessibleContent(content)
        }
    }

    private func accessibleContent(_ content: some View) -> some View {
        if isEnabled {
            content
                .accessibilityValue(Text(verbatim: value))
                .accessibilityAdjustableAction { direction in
                    adjustment(direction)
                }
        } else {
            content
                .accessibilityValue(Text(verbatim: value))
        }
    }
}
