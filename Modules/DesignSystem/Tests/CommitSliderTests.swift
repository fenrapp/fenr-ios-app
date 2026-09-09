@testable import DesignSystem
import SwiftUI
import Testing

@Suite("Commit slider interaction")
struct CommitSliderTests {
    @Test("An explicit retry can commit an unchanged value exactly once")
    func unchangedRetry() {
        var state = CommitSliderInteractionState(value: 35, bounds: 0 ... 100)
        #expect(state.finishEditing(
            externalValue: 35, bounds: 0 ... 100, isEnabled: true, allowsUnchangedCommit: true
        ) == nil)
        state.beginEditing(isEnabled: true)
        #expect(state.finishEditing(
            externalValue: 35, bounds: 0 ... 100, isEnabled: true, allowsUnchangedCommit: true
        ) == 35)
        #expect(state.finishEditing(
            externalValue: 35, bounds: 0 ... 100, isEnabled: true, allowsUnchangedCommit: true
        ) == nil)
    }

    @Test("Synchronizes external values while inactive")
    func synchronizesExternalValue() {
        var state = CommitSliderInteractionState(value: 40, bounds: 20 ... 100)

        state.synchronize(externalValue: 75, bounds: 20 ... 100)

        #expect(state.displayedValue == 75)
        #expect(!state.isEditing)
    }

    @Test("Keeps the drag value when external state changes")
    func preservesValueDuringDrag() {
        var state = CommitSliderInteractionState(value: 40, bounds: 20 ... 100)
        state.beginEditing(isEnabled: true)
        state.updateDisplayedValue(65, bounds: 20 ... 100, isEnabled: true)

        state.synchronize(externalValue: 45, bounds: 20 ... 100)

        #expect(state.displayedValue == 65)
        #expect(state.isEditing)
    }

    @Test("Clamps the drag value when the range changes")
    func clampsValueForChangingRange() {
        var state = CommitSliderInteractionState(value: 80, bounds: 20 ... 100)
        state.beginEditing(isEnabled: true)

        state.synchronize(externalValue: 80, bounds: 20 ... 60)

        #expect(state.displayedValue == 60)
        #expect(state.isEditing)
    }

    @Test("Disabled interaction neither drags nor commits")
    func disabledInteractionDoesNotCommit() {
        var state = CommitSliderInteractionState(value: 40, bounds: 20 ... 100)

        state.beginEditing(isEnabled: false)
        state.updateDisplayedValue(65, bounds: 20 ... 100, isEnabled: false)
        let result = state.finishEditing(
            externalValue: 40,
            bounds: 20 ... 100,
            isEnabled: false
        )

        #expect(state.displayedValue == 40)
        #expect(result == nil)
    }

    @Test("Does not commit an unchanged value")
    func unchangedValueDoesNotCommit() {
        var state = CommitSliderInteractionState(value: 40, bounds: 20 ... 100)
        state.beginEditing(isEnabled: true)

        let result = state.finishEditing(
            externalValue: 40,
            bounds: 20 ... 100,
            isEnabled: true
        )

        #expect(result == nil)
    }

    @Test("Commits a changed value exactly once")
    func changedValueCommitsOnce() {
        var state = CommitSliderInteractionState(value: 40, bounds: 20 ... 100)
        state.beginEditing(isEnabled: true)
        state.updateDisplayedValue(65, bounds: 20 ... 100, isEnabled: true)

        let firstResult = state.finishEditing(
            externalValue: 40,
            bounds: 20 ... 100,
            isEnabled: true
        )
        let secondResult = state.finishEditing(
            externalValue: 40,
            bounds: 20 ... 100,
            isEnabled: true
        )

        #expect(firstResult == 65)
        #expect(secondResult == nil)
    }

    @Test("Gradient layout keeps its thumb inside the available width")
    func gradientLayoutPositions() {
        let layout = CommitSliderLayout(
            bounds: -100 ... 100,
            width: 300,
            thumbDiameter: 28
        )

        #expect(layout.trackOrigin == 14)
        #expect(layout.trackWidth == 272)
        #expect(layout.thumbOrigin(for: -100) == 0)
        #expect(layout.thumbOrigin(for: 0) == 136)
        #expect(layout.thumbOrigin(for: 100) == 272)
        #expect(layout.centerPosition == 150)
    }

    @Test("Gradient layout snaps drag positions to the configured step")
    func gradientLayoutSnapsValues() {
        let layout = CommitSliderLayout(
            bounds: 10 ... 60,
            width: 128,
            thumbDiameter: 28
        )

        #expect(layout.value(at: 0, step: 5) == 10)
        #expect(layout.value(at: 67, step: 5) == 35)
        #expect(layout.value(at: 200, step: 5) == 60)
    }

    @Test("A track tap resolves to one snapped commit")
    func trackTapCommitsOnce() {
        let bounds = 0.0 ... 100.0
        let layout = CommitSliderLayout(
            bounds: bounds,
            width: 128,
            thumbDiameter: 28
        )
        var state = CommitSliderInteractionState(value: 20, bounds: bounds)

        state.beginEditing(isEnabled: true)
        state.updateDisplayedValue(
            layout.value(at: 67, step: 5),
            bounds: bounds,
            isEnabled: true
        )

        #expect(state.finishEditing(externalValue: 20, bounds: bounds, isEnabled: true) == 55)
        #expect(state.finishEditing(externalValue: 20, bounds: bounds, isEnabled: true) == nil)
    }

    @Test("Collapsed gradient layout remains stable")
    func collapsedGradientLayout() {
        let layout = CommitSliderLayout(
            bounds: 40 ... 40,
            width: 20,
            thumbDiameter: 28
        )

        #expect(layout.trackOrigin == 10)
        #expect(layout.trackWidth == 0)
        #expect(layout.progressWidth(for: 40) == 0)
        #expect(layout.thumbOrigin(for: 40) == -4)
        #expect(layout.value(at: 10, step: 5) == 40)
    }

    @Test("Accessibility adjustment uses the step and clamps to bounds")
    func accessibilityAdjustment() {
        #expect(
            CommitSliderValueMath.adjustedValue(
                95,
                direction: .increment,
                bounds: 0 ... 100,
                step: 10
            ) == 100
        )
        #expect(
            CommitSliderValueMath.adjustedValue(
                5,
                direction: .decrement,
                bounds: 0 ... 100,
                step: 10
            ) == 0
        )
    }

    @Test("Invalid steps fall back to a positive value")
    func invalidStepFallback() {
        #expect(CommitSliderValueMath.validStep(5) == 5)
        #expect(CommitSliderValueMath.validStep(0) > 0)
        #expect(CommitSliderValueMath.validStep(-1) > 0)
        #expect(CommitSliderValueMath.validStep(.nan) > 0)
    }

    @Test("Drag intent waits for movement and accepts only horizontal drags")
    func dragIntentDirection() {
        #expect(CommitSliderDragIntent.resolve(translation: .init(width: 4, height: 2)) == .undecided)
        #expect(CommitSliderDragIntent.resolve(translation: .init(width: 12, height: 3)) == .horizontal)
        #expect(CommitSliderDragIntent.resolve(translation: .init(width: 3, height: 12)) == .vertical)
        #expect(CommitSliderDragIntent.resolve(translation: .init(width: 10, height: 10)) == .vertical)
    }
}
