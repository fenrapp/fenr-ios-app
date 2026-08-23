import SwiftUI

struct DashboardSpeedometer: View {
    let speed: RideDashboardMeasurement?
    let maximum: RideDashboardMeasurement
    let reduceMotion: Bool

    var body: some View {
        DashboardGauge(
            mode: .speed(speed: speed, maximum: maximum),
            reduceMotion: reduceMotion
        )
    }
}
