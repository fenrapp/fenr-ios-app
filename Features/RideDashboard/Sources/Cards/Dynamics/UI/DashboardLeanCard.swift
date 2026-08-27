import SwiftUI

struct DashboardLeanCard: View {
    let state: DashboardRideDynamicsViewData
    let calibrate: () -> Void

    var body: some View {
        DashboardDynamicsAngleCard(
            title: "RIDE DYNAMICS · LEAN",
            status: state.status,
            angleDegrees: state.leanDegrees,
            maximumAngleDegrees: Constants.maximumLeanDegrees,
            vehiclePerspective: .front,
            angleText: state.leanText,
            directionText: state.leanDirectionText,
            maximums: [
                .init(label: "MAX LEFT", value: state.maximumLeftLeanText),
                .init(label: "MAX RIGHT", value: state.maximumRightLeanText)
            ],
            canCalibrate: state.canCalibrate,
            calibrate: calibrate
        )
    }

    private enum Constants {
        static let maximumLeanDegrees = 60.0
    }
}
