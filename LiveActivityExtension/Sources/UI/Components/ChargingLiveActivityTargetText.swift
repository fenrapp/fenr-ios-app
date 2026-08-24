import DesignSystem
import SwiftUI

struct ChargingLiveActivityTargetText: View {
    let percent: Int?

    var body: some View {
        if let percent {
            Text(ChargingLiveActivityText.target(percent))
                .font(.caption2.weight(.medium))
                .foregroundStyle(DesignColor.secondaryText)
                .lineLimit(ChargingLiveActivityText.singleLineLimit)
        }
    }
}
