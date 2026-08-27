import SwiftUI

struct DashboardPitchCard: View {
    let state: DashboardRideDynamicsViewData
    let reduceMotion: Bool
    let calibrate: () -> Void

    var body: some View {
        DashboardDynamicsInstrumentCard(
            title: "PITCH",
            status: state.status,
            angleDegrees: state.pitchDegrees,
            maximumAngleDegrees: Constants.maximumPitchDegrees,
            vehiclePerspective: .side,
            angleText: state.pitchText,
            directionText: state.pitchDirectionText,
            maximums: [
                .init(label: "MAX UP", value: state.maximumUphillPitchText),
                .init(label: "MAX DOWN", value: state.maximumDownhillPitchText, trailing: true)
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
