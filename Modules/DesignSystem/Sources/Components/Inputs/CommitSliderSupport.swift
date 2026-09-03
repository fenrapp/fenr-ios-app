import SwiftUI

enum CommitSliderConstants {
    static let minimumControlHeight: CGFloat = 44
    static let trackHeight: CGFloat = 10
    static let thumbDiameter: CGFloat = 28
    static let centerMarkerWidth: CGFloat = 2
    static let centerMarkerOverhang: CGFloat = 8
    static let haloExpansion: CGFloat = 16
    static let haloOpacity = 0.28
    static let haloBlurRadius: CGFloat = 5
    static let strokeWidth: CGFloat = 2
    static let highContrastStrokeWidth: CGFloat = 3
    static let thumbShadowOpacity = 0.18
    static let thumbShadowRadius: CGFloat = 3
    static let thumbShadowOffset: CGFloat = 2
    static let editingScale = 1.12
    static let animationDuration = 0.2
    static let backgroundTrackOpacity = 0.35
    static let highContrastBackgroundTrackOpacity = 0.65
    static let centerMarkerOpacity = 0.55
    static let highContrastCenterMarkerOpacity = 0.9
    static let disabledOpacity = 0.45
    static let dragIntentThreshold: CGFloat = 8
}

enum CommitSliderDragIntent: Equatable {
    case undecided
    case horizontal
    case vertical

    static func resolve(translation: CGSize) -> Self {
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)
        guard max(horizontalDistance, verticalDistance) >= CommitSliderConstants.dragIntentThreshold else {
            return .undecided
        }
        return horizontalDistance > verticalDistance ? .horizontal : .vertical
    }
}

struct CommitSliderLayout {
    let bounds: ClosedRange<Double>
    let width: CGFloat
    let thumbDiameter: CGFloat

    var trackOrigin: CGFloat {
        min(thumbDiameter / 2, max(width, .zero) / 2)
    }

    var trackWidth: CGFloat {
        max(width - thumbDiameter, .zero)
    }

    var centerPosition: CGFloat {
        trackOrigin + trackWidth / 2
    }

    func progressWidth(for value: Double) -> CGFloat {
        normalizedPosition(for: value) * trackWidth
    }

    func thumbOrigin(for value: Double) -> CGFloat {
        trackOrigin + progressWidth(for: value) - thumbDiameter / 2
    }

    func value(at location: CGFloat, step: Double) -> Double {
        guard trackWidth > .zero else { return bounds.lowerBound }
        let normalizedLocation = Double((location - trackOrigin) / trackWidth)
        let rawValue = bounds.lowerBound + normalizedLocation * (bounds.upperBound - bounds.lowerBound)
        return CommitSliderValueMath.snappedValue(rawValue, bounds: bounds, step: step)
    }

    private func normalizedPosition(for value: Double) -> CGFloat {
        guard bounds.lowerBound != bounds.upperBound else { return .zero }
        let clampedValue = min(max(value, bounds.lowerBound), bounds.upperBound)
        return CGFloat((clampedValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound))
    }
}

enum CommitSliderValueMath {
    static func validStep(_ step: Double) -> Double {
        guard step.isFinite, step > .zero else { return .leastNonzeroMagnitude }
        return step
    }

    static func snappedValue(
        _ value: Double,
        bounds: ClosedRange<Double>,
        step: Double
    ) -> Double {
        let clampedValue = min(max(value, bounds.lowerBound), bounds.upperBound)
        let validStep = validStep(step)
        let stepCount = ((clampedValue - bounds.lowerBound) / validStep).rounded()
        let snappedValue = bounds.lowerBound + stepCount * validStep
        return min(max(snappedValue, bounds.lowerBound), bounds.upperBound)
    }

    static func adjustedValue(
        _ value: Double,
        direction: AccessibilityAdjustmentDirection,
        bounds: ClosedRange<Double>,
        step: Double
    ) -> Double {
        let delta: Double
        switch direction {
        case .increment:
            delta = validStep(step)
        case .decrement:
            delta = -validStep(step)
        @unknown default:
            delta = .zero
        }
        return snappedValue(value + delta, bounds: bounds, step: step)
    }
}

struct CommitSliderInteractionState: Equatable {
    private(set) var displayedValue: Double
    private(set) var isEditing = false

    init(value: Double, bounds: ClosedRange<Double>) {
        displayedValue = Self.clamped(value, to: bounds)
    }

    mutating func synchronize(externalValue: Double, bounds: ClosedRange<Double>) {
        displayedValue = Self.clamped(isEditing ? displayedValue : externalValue, to: bounds)
    }

    mutating func updateDisplayedValue(
        _ value: Double,
        bounds: ClosedRange<Double>,
        isEnabled: Bool
    ) {
        guard isEnabled else { return }
        isEditing = true
        displayedValue = Self.clamped(value, to: bounds)
    }

    mutating func beginEditing(isEnabled: Bool) {
        guard isEnabled else { return }
        isEditing = true
    }

    mutating func finishEditing(
        externalValue: Double,
        bounds: ClosedRange<Double>,
        isEnabled: Bool
    ) -> Double? {
        guard isEditing else { return nil }
        isEditing = false
        displayedValue = Self.clamped(displayedValue, to: bounds)

        guard
            isEnabled,
            displayedValue != Self.clamped(externalValue, to: bounds)
        else { return nil }
        return displayedValue
    }

    mutating func cancelEditing(externalValue: Double, bounds: ClosedRange<Double>) {
        isEditing = false
        displayedValue = Self.clamped(externalValue, to: bounds)
    }

    private static func clamped(_ value: Double, to bounds: ClosedRange<Double>) -> Double {
        min(max(value, bounds.lowerBound), bounds.upperBound)
    }
}
