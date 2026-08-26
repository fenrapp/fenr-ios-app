import SwiftUI

struct DashboardChargingHapticFeedback: ViewModifier {
    let selectionTrigger: Int
    let status: ChargingDashboardStatusViewData?

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.selection, trigger: selectionTrigger)
            .sensoryFeedback(.success, trigger: status) { previous, current in
                previous?.showsActivityIndicator == true && current == nil
            }
            .sensoryFeedback(.error, trigger: status) { previous, current in
                previous != current && current?.emphasis == .failure
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
