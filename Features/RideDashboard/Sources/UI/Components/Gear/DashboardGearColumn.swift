import DesignSystem
import SwiftUI

struct DashboardGearColumn: View {
    let runState: RideDashboardRunState
    let modeIndex: Int?

    var body: some View {
        VStack(spacing: .zero) {
            Spacer(minLength: .zero)
            DashboardGearPanel(display: display, tint: tint)
            Spacer(minLength: .zero)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var display: DashboardGearPanel.Display {
        switch runState {
        case .neutral, .charging:
            .text("N")
        case .ride:
            .text(modeIndex.map(String.init) ?? "—")
        case .crawlForward:
            .crawlForward
        case .crawlReverse:
            .crawlReverse
        case .off:
            .text("OFF")
        case .offline:
            .text("—")
        }
    }

    private var tint: Color {
        switch runState {
        case .ride, .neutral, .charging, .crawlForward, .crawlReverse:
            DesignColor.positive
        case .offline, .off:
            .primary
        }
    }
}
