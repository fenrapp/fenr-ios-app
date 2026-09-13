import SwiftUI

#if DEBUG
#Preview {
    WatchRideDashboardContent(state: .init(
        hasData: true, isStale: false, status: "Live from iPhone", batteryPercent: 38, map: "4", traction: "12%"
    ))
}
#endif
