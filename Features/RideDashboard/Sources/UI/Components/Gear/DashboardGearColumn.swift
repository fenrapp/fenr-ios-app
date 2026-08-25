import SwiftUI

struct DashboardGearColumn: View {
    let state: DashboardGearViewData

    var body: some View {
        VStack(spacing: .zero) {
            Spacer(minLength: .zero)
            DashboardGearPanel(state: state)
            Spacer(minLength: .zero)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

}
