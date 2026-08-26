import SwiftUI
import UIKit

struct DashboardChargingHapticFeedback: ViewModifier {
    let selectionTrigger: Int
    let status: ChargingDashboardStatusViewData?

    @State private var previousStatus: ChargingDashboardStatusViewData?

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .sensoryFeedback(.selection, trigger: selectionTrigger)
                .sensoryFeedback(.success, trigger: status) { previous, current in
                    previous?.showsActivityIndicator == true && current == nil
                }
                .sensoryFeedback(.error, trigger: status) { previous, current in
                    previous != current && current?.emphasis == .failure
                }
        } else {
            content
                .onAppear { previousStatus = status }
                .onChange(of: selectionTrigger) { _ in
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                .onChange(of: status) { current in
                    playLegacyStatusFeedback(from: previousStatus, to: current)
                    previousStatus = current
                }
        }
    }

    private func playLegacyStatusFeedback(
        from previous: ChargingDashboardStatusViewData?,
        to current: ChargingDashboardStatusViewData?
    ) {
        if previous?.showsActivityIndicator == true, current == nil {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else if previous != current, current?.emphasis == .failure {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

extension View {
    func dashboardChargingHapticFeedback(
        selectionTrigger: Int,
        status: ChargingDashboardStatusViewData?
    ) -> some View {
        modifier(DashboardChargingHapticFeedback(
            selectionTrigger: selectionTrigger,
            status: status
        ))
    }
}
