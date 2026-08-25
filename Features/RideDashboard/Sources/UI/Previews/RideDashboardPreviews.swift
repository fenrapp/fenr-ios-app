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
                    batteryPercent: 78,
                    odometer: .init(valueText: "180.0", unitText: "km", animationValue: 180),
                    gear: previewGear("2"),
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    indicators: previewIndicators(highBeam: true, brake: true)
                )
            ),
            chargingViewModel: ChargingDashboardPreviewFactory.makeViewModel(state: .init()),
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
                    batteryPercent: 34,
                    odometer: .init(valueText: "180.0", unitText: "km", animationValue: 180),
                    gear: previewGear("3"),
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    indicators: previewIndicators(rightTurn: true)
                )
            ),
            chargingViewModel: ChargingDashboardPreviewFactory.makeViewModel(state: .init()),
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
                    batteryPercent: 12,
                    odometer: .init(valueText: "180.0", unitText: "km", animationValue: 180),
                    gear: previewGear("4"),
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    indicators: previewIndicators(fault: true)
                )
            ),
            chargingViewModel: ChargingDashboardPreviewFactory.makeViewModel(state: .init()),
            onDiagnostics: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Dashboard disconnected") {
    NavigationStack {
        RideDashboardView(
            viewModel: RideDashboardPreviewFactory.makeViewModel(state: .init()),
            chargingViewModel: ChargingDashboardPreviewFactory.makeViewModel(state: .init()),
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
        chargingViewModel: ChargingDashboardPreviewFactory.makeViewModel(
            state: .init(
                gauge: .init(
                    batteryPercent: 82,
                    targetPercent: 100
                ),
                maximumPower: .init(valueText: "6.2", unitText: "kW", animationValue: 6.2),
                reportedCurrent: .init(valueText: "13.6", unitText: "A", animationValue: 13.6)
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
        unit: "km/h",
        progress: value / 180,
        emphasis: emphasis,
        accessibilityLabel: "Speed \(Int(value)) km/h"
    )
}

private func previewGear(_ text: String) -> DashboardGearViewData {
    .init(display: .text(text), isActive: true, accessibilityLabel: "Gear \(text)")
}

private func previewIndicators(
    highBeam: Bool = false,
    brake: Bool = false,
    rightTurn: Bool = false,
    fault: Bool = false
) -> [DashboardIndicatorViewData] {
    [
        previewIndicator("highBeam", "headlight.high.beam", "High beam", highBeam, .informational),
        previewIndicator("leftTurn", "arrow.left", "Left turn", false, .positive),
        previewIndicator("brake", "hand.raised.fill", "Brake", brake, .warning),
        previewIndicator("rightTurn", "arrow.right", "Right turn", rightTurn, .positive),
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
