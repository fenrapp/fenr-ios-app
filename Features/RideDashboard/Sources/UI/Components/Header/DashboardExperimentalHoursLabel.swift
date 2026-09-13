import DesignSystem
import SwiftUI

struct DashboardExperimentalHoursLabel: View {
    let state: DashboardExperimentalHoursViewData
    @State private var showsExplanation = false

    var body: some View {
        Button {
            showsExplanation = true
        } label: {
            Label {
                Text(verbatim: state.valueText)
            } icon: {
                Image(systemName: "clock")
            }
            .font(.system(size: Constants.fontSize, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(Constants.minimumScaleFactor)
        }
        .buttonStyle(.plain)
        .foregroundStyle(DesignColor.primaryText)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityIdentifier("dashboard.experimentalHours")
        .alert(.rideDashboardExperimentalHoursTitle, isPresented: $showsExplanation) {
            Button(.rideDashboardExperimentalHoursDismiss, role: .cancel) {}
        } message: {
            Text(.rideDashboardExperimentalHoursExplanation(state.rawCounterText))
        }
    }

    private enum Constants {
        static let fontSize: CGFloat = 16
        static let minimumScaleFactor = 0.75
    }
}
