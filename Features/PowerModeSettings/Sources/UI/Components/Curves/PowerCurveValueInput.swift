import SwiftUI

struct PowerCurveValueInput: View {
    let point: PowerCurvePointViewData
    let unit: String
    let commit: (Double) -> Void

    var body: some View {
        PowerModeValueInput(
            title: String(localized: .powerCurvePointAccessibility(point.rpmText)),
            value: point.value, bounds: 0 ... point.maximum, wholeNumbersOnly: false,
            hint: .powerCurveInputDraftHint, confirmationTitle: .powerCurveSetPoint,
            unit: unit, commit: commit
        )
    }
}
