import SwiftUI

struct DashboardPitchCard: View {
    let state: DashboardRideDynamicsViewData
    let reduceMotion: Bool
    let calibrate: () -> Void

    var body: some View {
        DashboardDynamicsInstrumentCard(
            title: rideDashboardLocalized(.rideDashboardDynamicsPitchTitle),
            status: state.status,
            angleDegrees: state.pitchDegrees,
            maximumAngleDegrees: Constants.maximumPitchDegrees,
            vehiclePerspective: .side,
            angleText: state.pitchText,
            directionText: state.pitchDirectionText,
            maximums: [
                .init(
                    label: rideDashboardLocalized(.rideDashboardDynamicsPitchMaximumUp),
                    value: state.maximumUphillPitchText
                ),
                .init(
                    label: rideDashboardLocalized(.rideDashboardDynamicsPitchMaximumDown),
                    value: state.maximumDownhillPitchText,
                    trailing: true
                )
            ],
            canCalibrate: state.canCalibrate,
            reduceMotion: reduceMotion,
            calibrate: calibrate
        )
    }

    private enum Constants {
        static let maximumPitchDegrees = 45.0
    }
}
