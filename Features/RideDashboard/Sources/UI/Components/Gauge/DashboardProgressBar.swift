import SwiftUI

struct DashboardProgressBar: View {
    let state: DashboardProgressBarViewData
    var layout: DashboardProgressBarLayout = .regular

    @ViewBuilder
    var body: some View {
        switch state {
        case .hidden:
            EmptyView()
        case .speed(let progress):
            DashboardSpeedProgressBar(progress: progress, height: layout.trackHeight)
        case .energy(let regenerationProgress, let consumptionProgress, let accessibilityLabel):
            DashboardEnergyProgressBar(
                regenerationProgress: regenerationProgress,
                consumptionProgress: consumptionProgress,
                layout: layout
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
        }
    }
}
