#if DEBUG
enum DashboardDynamicsPreviewFixtures {
    static let available = DashboardRideDynamicsViewData(
        status: .live,
        leanDegrees: -18,
        leanText: "18°",
        leanDirectionText: "LEFT",
        maximumLeftLeanText: "34°",
        maximumRightLeanText: "29°",
        pitchDegrees: 6,
        pitchText: "6°",
        pitchDirectionText: "UP",
        maximumUphillPitchText: "14°",
        maximumDownhillPitchText: "11°",
        headingDegrees: 336,
        isHeadingAvailable: true,
        headingText: "336°",
        cardinalDirectionText: "NNW",
        headingSourceText: "GPS",
        altitudeText: "1,045 m",
        latitudeText: "40°25′35″ N",
        longitudeText: "3°42′14″ W",
        canCalibrate: true
    )

    static let withoutLocation = DashboardRideDynamicsViewData(
        status: .live,
        headingDegrees: 74,
        isHeadingAvailable: true,
        headingText: "74°",
        cardinalDirectionText: "ENE",
        headingSourceText: "COMPASS",
        altitudeText: nil,
        canCalibrate: true
    )

    static let calibrationRequired = DashboardRideDynamicsViewData(
        status: .calibrating,
        maximumLeftLeanText: "34°",
        maximumRightLeanText: "29°",
        canCalibrate: true
    )
}
#endif
