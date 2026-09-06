import SwiftUI

#Preview("Power telemetry rows") {
    List {
        DiagnosticsPowerModeRow(configuration: previewConfiguration)
        DiagnosticsPowerTierEvidenceView(metrics: previewTierMetrics)
    }
}

#Preview("Power telemetry rows - large text") {
    List {
        DiagnosticsPowerModeRow(configuration: previewConfiguration)
        DiagnosticsPowerTierEvidenceView(metrics: previewTierMetrics)
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

private let previewConfiguration = BikeDiagnosticsPowerModeViewData(
    id: 0,
    title: "Map 1",
    isActive: true,
    metrics: [
        .init(id: "power", title: "Power", value: "60 HP"),
        .init(id: "regen", title: "Regen", value: "40%"),
        .init(id: "traction", title: "Traction", value: "50%"),
        .init(id: "regenTraction", title: "Regen traction", value: "25%")
    ]
)

private let previewTierMetrics: [BikeDiagnosticsMetricViewData] = [
    .init(id: "declaredTier", title: "Declared", value: "Standard"),
    .init(id: "verifiedTier", title: "Verified", value: "Standard"),
    .init(id: "powerTierEvidence", title: "Evidence", value: "Read from the connected bike")
]
