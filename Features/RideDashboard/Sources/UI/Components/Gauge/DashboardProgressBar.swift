import SwiftUI

struct DashboardProgressBar: View {
    let state: DashboardProgressBarViewData

    @ViewBuilder
    var body: some View {
        switch state {
        case .hidden:
            EmptyView()
        case .speed(let progress):
            DashboardSpeedProgressBar(progress: progress)
        case .energy(let regenerationProgress, let consumptionProgress, let accessibilityLabel):
            DashboardEnergyProgressBar(
                regenerationProgress: regenerationProgress,
                consumptionProgress: consumptionProgress
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
        }
    }
}
