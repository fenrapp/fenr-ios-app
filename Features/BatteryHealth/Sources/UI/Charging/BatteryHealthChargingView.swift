import SwiftUI

struct BatteryHealthChargingView: View {
    let state: BatteryHealthChargingViewData
    let setPowerLimit: (Double) -> Void
    let setChargeTarget: (Double) -> Void

    var body: some View {
        List {
            if !state.metrics.isEmpty {
                Section(BatteryHealthText.chargingStatus) {
                    BatteryHealthMetricRows(metrics: state.metrics)
                }
            }

            if state.control.isVisible {
                Section(BatteryHealthText.supportedControls) {
                    ChargePowerControlView(
                        state: state.control,
                        setPowerLimit: setPowerLimit,
                        setChargeTarget: setChargeTarget
                    )
                }
            } else {
                Section(BatteryHealthText.supportedControls) {
                    ContentUnavailableView(
                        BatteryHealthText.controlsUnavailable,
                        systemImage: "bolt.slash",
                        description: Text(BatteryHealthText.controlsUnavailableDetail)
                    )
                }
            }
        }
    }
}
