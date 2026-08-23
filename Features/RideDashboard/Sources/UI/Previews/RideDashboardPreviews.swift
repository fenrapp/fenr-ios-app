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
                    speed: .init(value: 20, unit: "km/h"),
                    batteryPercent: 78,
                    odometer: .init(value: 180, unit: "km"),
                    modeIndex: 2,
                    runState: .ride,
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    isHighBeamOn: true,
                    isBrakeActive: true
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
                    speed: .init(value: 142, unit: "km/h"),
                    batteryPercent: 34,
                    odometer: .init(value: 180, unit: "km"),
                    modeIndex: 3,
                    runState: .ride,
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    isRightBlinkerOn: true
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
                    speed: .init(value: 96, unit: "km/h"),
                    batteryPercent: 12,
                    odometer: .init(value: 180, unit: "km"),
                    modeIndex: 4,
                    runState: .ride,
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    isFaultActive: true
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
                runState: .charging,
                connectionDetail: "Live telemetry active",
                hasTelemetry: true
            )
        ),
        chargingViewModel: ChargingDashboardPreviewFactory.makeViewModel(
            state: .init(
                batteryPercent: 82,
                maximumPower: .init(value: 6.2, unit: "kW"),
                reportedCurrent: .init(value: 13.6, unit: "A"),
                targetStateOfChargePercent: 100
            )
        ),
        onDiagnostics: {}
    )
    .frame(width: DashboardPreviewConstants.landscapeWidth, height: DashboardPreviewConstants.landscapeHeight)
}
#endif
