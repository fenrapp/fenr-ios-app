import SwiftUI

#if DEBUG
private enum DashboardPreviewConstants {
    static let landscapeWidth: CGFloat = 844
    static let landscapeHeight: CGFloat = 390
}

#Preview("Dashboard portrait") {
    NavigationStack {
        RideDashboardView(
            viewModel: RideDashboardPreviewFactory.makeViewModel(
                state: .init(
                    speedometer: previewSpeedometer(value: 20),
                    battery: previewBattery(percentage: 78, emphasis: .positive),
                    odometer: .init(valueText: "180.0", unitText: "km", animationValue: 180),
                    gear: previewGear("2"),
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    indicators: previewIndicators(highBeam: true, brake: true)
                )
            ),
            onDiagnostics: {}
        )
    }
}

#Preview("Dashboard landscape") {
    NavigationStack {
        RideDashboardView(
            viewModel: RideDashboardPreviewFactory.makeViewModel(
                state: .init(
                    speedometer: previewSpeedometer(value: 142, emphasis: .warning),
                    battery: previewBattery(percentage: 34, emphasis: .warning),
                    odometer: .init(valueText: "180.0", unitText: "km", animationValue: 180),
                    gear: previewGear("3"),
                    powerMode: previewPowerMode(horsepower: "40", regen: "30"),
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    indicators: previewIndicators(rightTurn: true)
                )
            ),
            onDiagnostics: {}
        )
    }
    .frame(width: DashboardPreviewConstants.landscapeWidth, height: DashboardPreviewConstants.landscapeHeight)
    .preferredColorScheme(.dark)
}

#Preview("Dashboard low battery") {
    NavigationStack {
        RideDashboardView(
            viewModel: RideDashboardPreviewFactory.makeViewModel(
                state: .init(
                    speedometer: previewSpeedometer(value: 96, emphasis: .positive),
                    battery: previewBattery(percentage: 12, emphasis: .critical),
                    odometer: .init(valueText: "180.0", unitText: "km", animationValue: 180),
                    gear: previewGear("4"),
                    powerMode: previewPowerMode(horsepower: "50", regen: "40"),
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    indicators: previewIndicators(fault: true)
                )
            ),
            onDiagnostics: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Dashboard disconnected") {
    NavigationStack {
        RideDashboardView(
            viewModel: RideDashboardPreviewFactory.makeViewModel(state: .init()),
            onDiagnostics: {}
        )
    }
}

#Preview("Dashboard charging") {
    RideDashboardView(
        viewModel: RideDashboardPreviewFactory.makeViewModel(
            state: .init(
                gear: previewGear("N"),
                isCharging: true,
                connectionDetail: "Live telemetry active",
                hasTelemetry: true,
                indicators: previewIndicators()
            )
        ),
        onDiagnostics: {}
    )
    .frame(width: DashboardPreviewConstants.landscapeWidth, height: DashboardPreviewConstants.landscapeHeight)
}

private func previewSpeedometer(
    value: Double,
    emphasis: DashboardGaugeEmphasis = .informational
) -> DashboardSpeedometerViewData {
    .init(
        value: value,
        valueText: value.rounded().formatted(.number.precision(.fractionLength(0))),
        unit: "km/h",
        progress: value / 180,
        emphasis: emphasis,
        accessibilityLabel: "Speed \(Int(value)) km/h"
    )
}

private func previewBattery(
    percentage: Int,
    emphasis: RideDashboardViewState.Battery.Emphasis
) -> RideDashboardViewState.Battery {
    .init(
        percentageText: "\(percentage)%",
        progress: Double(percentage) / 100,
        emphasis: emphasis,
        accessibilityLabel: "Battery \(percentage) percent"
    )
}

private func previewGear(_ text: String) -> DashboardGearViewData {
    .init(display: .text(text), isActive: true, accessibilityLabel: "Gear \(text)")
}

private func previewPowerMode(horsepower: String, regen: String) -> DashboardPowerModeViewData {
    .init(
        horsepower: horsepower,
        regenerativeBraking: regen,
        isVisible: true
    )
}

private func previewIndicators(
    highBeam: Bool = false,
    brake: Bool = false,
    rightTurn: Bool = false,
    fault: Bool = false
) -> [DashboardIndicatorViewData] {
    [
        previewIndicator("highBeam", "headlight.high.beam", "High beam", highBeam, .informational),
        previewIndicator("leftTurn", "arrow.left", "Left turn", false, .warning),
        previewIndicator("brake", "exclamationmark.circle.fill", "Brake", brake, .critical),
        previewIndicator("rightTurn", "arrow.right", "Right turn", rightTurn, .warning),
        previewIndicator("fault", "exclamationmark.triangle.fill", "Fault", fault, .critical)
    ]
}

private func previewIndicator(
    _ id: String,
    _ symbolName: String,
    _ label: String,
    _ isActive: Bool,
    _ emphasis: DashboardIndicatorEmphasis
) -> DashboardIndicatorViewData {
    .init(
        id: id,
        symbolName: symbolName,
        accessibilityLabel: label,
        accessibilityValue: isActive ? "On" : "Off",
        isActive: isActive,
        emphasis: emphasis
    )
}
#endif
