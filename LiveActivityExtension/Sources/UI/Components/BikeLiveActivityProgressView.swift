import SwiftUI

struct BikeLiveActivityProgressView: View {
    let state: BikeLiveActivityAttributes.ContentState

    var body: some View {
        ProgressView(value: progressValue)
            .tint(BikeLiveActivityPresentation.tint(for: state.phase))
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
