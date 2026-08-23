import SwiftUI

struct DashboardGauge: View {
    let mode: DashboardGaugeMode
    let reduceMotion: Bool

    private var progress: Double {
        min(max(mode.value / mode.maximumValue, .zero), 1)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DashboardGaugeArc(
                progress: progress,
                color: mode.progressColor,
                showsTicks: mode.showsTicks,
                targetProgress: mode.targetProgress,
                reduceMotion: reduceMotion
            )
            DashboardGaugeReadout(mode: mode, reduceMotion: reduceMotion)
                .padding(.bottom, Constants.readoutBottomInset)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode.accessibilityLabel)
    }

    private enum Constants {
        static let readoutBottomInset: CGFloat = 16
    }
}
