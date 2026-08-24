import DesignSystem
import SwiftUI

struct BikeLiveActivityTargetText: View {
    let percent: Int?

    var body: some View {
        if let percent {
            Text(BikeLiveActivityText.target(percent))
                .font(.caption2.weight(.medium))
                .foregroundStyle(DesignColor.secondaryText)
                .lineLimit(BikeLiveActivityText.singleLineLimit)
        }
    }
}
