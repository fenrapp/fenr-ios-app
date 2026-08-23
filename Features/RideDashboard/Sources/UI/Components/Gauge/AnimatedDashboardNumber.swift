import SwiftUI

struct AnimatedDashboardNumber: AnimatableModifier {
    var value: Double
    let formatter: (Double) -> String

    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    func body(content _: Content) -> some View {
        Text(formatter(value))
            .monospacedDigit()
    }
}

extension View {
    func animatedDashboardNumber(_ value: Double, formatter: @escaping (Double) -> String) -> some View {
        modifier(AnimatedDashboardNumber(value: value, formatter: formatter))
    }
}
