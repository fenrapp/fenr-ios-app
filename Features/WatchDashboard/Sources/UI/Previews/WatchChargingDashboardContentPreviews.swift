import SwiftUI

#if DEBUG
#Preview {
    WatchChargingDashboardContent(state: .init(
        hasData: true, isCharging: true, isStale: false, status: "Live from iPhone",
        batteryPercent: 88, chargingPower: "1 kW", chargingCurrent: "2.6 A", chargeETA: "51 min"
    ))
}
#endif
