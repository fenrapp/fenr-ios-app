import SwiftUI

struct AnimatedDashboardNumber: View, Animatable {
    var value: Double
    let formatter: (Double) -> String

    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(formatter(value))
            .monospacedDigit()
    }
}
