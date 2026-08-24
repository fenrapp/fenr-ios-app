import SwiftUI

struct ChargingLiveActivityProgressView: View {
    let state: ChargingLiveActivityAttributes.ContentState

    var body: some View {
        ProgressView(value: progressValue)
            .tint(ChargingLiveActivityPresentation.tint(for: state.phase))
    }

    private var progressValue: Double {
        guard let batteryPercent = state.batteryPercent else { return .zero }
        return min(
            max(Double(batteryPercent) / Constants.percentScale, .zero),
            Constants.progressMaximum
        )
    }

    private enum Constants {
        static let percentScale = 100.0
        static let progressMaximum = 1.0
    }
}
