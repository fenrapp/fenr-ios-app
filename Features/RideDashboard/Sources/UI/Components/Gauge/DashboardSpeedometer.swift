import DesignSystem
import SwiftUI

struct DashboardSpeedometer: View {
    let state: DashboardSpeedometerViewData
    let reduceMotion: Bool

    var body: some View {
        DashboardGauge(
            arc: {
                DashboardGaugeArc(
                    progress: state.progress,
                    color: progressColor,
                    showsTicks: true,
                    targetProgress: nil,
                    powerProgress: nil,
                    controlsAreEnabled: false,
                    activeControl: nil,
                    reduceMotion: reduceMotion
                )
            },
            readout: {
                DashboardGaugeReadout(
                    state: .init(
                        value: state.value,
                        unit: state.unit,
                        title: nil,
                        style: .number,
                        titleStyle: .status
                    ),
                    reduceMotion: reduceMotion
                )
            }
        )
        .accessibilityLabel(state.accessibilityLabel)
    }

    private var progressColor: Color {
        switch state.emphasis {
        case .informational: DesignColor.informational
        case .positive: DesignColor.positive
        case .warning: DesignColor.warning
        }
    }
}
