import SwiftUI

#Preview("Demo scenarios") {
    BikeDemoPanel(
        state: .init(scenarios: previewScenarios, selectedID: "charging"),
        onSelect: { _ in }
    )
}

#Preview("Demo scenario - large text") {
    List {
        BikeDemoScenarioRow(scenario: previewScenarios[0], isSelected: true)
        BikeDemoScenarioRow(scenario: previewScenarios[1], isSelected: false)
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

private let previewScenarios: [BikeDemoViewState.Scenario] = [
    .init(
        id: "charging", title: "Charging",
        detail: "Explore charge settings and live battery data.", icon: "bolt.fill"
    ),
    .init(
        id: "riding", title: "Riding",
        detail: "Explore the dashboard with simulated telemetry.", icon: "speedometer"
    )
]

#Preview("Demo introduction - ready") {
    BikeDemoIntroductionView(isBusy: false, hasError: false, onStart: {}, onCancel: {})
}

#Preview("Demo introduction - preparing") {
    BikeDemoIntroductionView(isBusy: true, hasError: false, onStart: {}, onCancel: {})
}

#Preview("Demo introduction - error - large text") {
    BikeDemoIntroductionView(isBusy: false, hasError: true, onStart: {}, onCancel: {})
        .environment(\.dynamicTypeSize, .accessibility3)
}
