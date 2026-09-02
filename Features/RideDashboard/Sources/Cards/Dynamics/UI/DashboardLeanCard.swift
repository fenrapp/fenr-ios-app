import SwiftUI

struct DashboardLeanCard: View {
    let state: DashboardRideDynamicsViewData
    let reduceMotion: Bool
    let calibrate: () -> Void

    var body: some View {
        DashboardDynamicsInstrumentCard(
            title: rideDashboardLocalized(.rideDashboardDynamicsLeanTitle),
            status: state.status,
            angleDegrees: state.leanDegrees,
            maximumAngleDegrees: Constants.maximumLeanDegrees,
            vehiclePerspective: .rear,
            angleText: state.leanText,
            directionText: state.leanDirectionText,
            maximums: [
                .init(
                    label: rideDashboardLocalized(.rideDashboardDynamicsLeanMaximumLeft),
                    value: state.maximumLeftLeanText
                ),
                .init(
                    label: rideDashboardLocalized(.rideDashboardDynamicsLeanMaximumRight),
                    value: state.maximumRightLeanText,
                    trailing: true
                )
            ],
            canCalibrate: state.canCalibrate,
            reduceMotion: reduceMotion,
            calibrate: calibrate
        )
    }

    private enum Constants {
        static let maximumLeanDegrees = 60.0
    }
}
