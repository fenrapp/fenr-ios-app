public struct DashboardRideDynamicsViewData: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case unavailable
        case calibrating
        case zeroing
        case live
        case signalLost

        var text: String {
            switch self {
            case .unavailable: rideDashboardLocalized(.rideDashboardDynamicsStatusUnavailable)
            case .calibrating: rideDashboardLocalized(.rideDashboardDynamicsStatusCalibrating)
            case .zeroing: rideDashboardLocalized(.rideDashboardDynamicsStatusZeroing)
            case .live: rideDashboardLocalized(.rideDashboardDynamicsStatusLive)
            case .signalLost: rideDashboardLocalized(.rideDashboardDynamicsStatusSignalLost)
            }
        }
    }

    public let status: Status
    public let leanDegrees: Double
    public let leanText: String
    public let leanDirectionText: String
    public let maximumLeftLeanText: String
    public let maximumRightLeanText: String
    public let pitchDegrees: Double
    public let pitchText: String
    public let pitchDirectionText: String
    public let maximumUphillPitchText: String
    public let maximumDownhillPitchText: String
    public let headingDegrees: Double
    public let isHeadingAvailable: Bool
    public let headingText: String
    public let cardinalDirectionText: String
    public let headingSourceText: String
    public let altimeter: DashboardAltitudeViewData
    public let altitudeText: String?
    public let latitudeText: String?
    public let longitudeText: String?
    public let canCalibrate: Bool

    public init(
        status: Status = .unavailable,
        leanDegrees: Double = .zero,
        leanText: String = "—",
        leanDirectionText: String? = nil,
        maximumLeftLeanText: String = "—",
        maximumRightLeanText: String = "—",
        pitchDegrees: Double = .zero,
        pitchText: String = "—",
        pitchDirectionText: String? = nil,
        maximumUphillPitchText: String = "—",
        maximumDownhillPitchText: String = "—",
        headingDegrees: Double = .zero,
        isHeadingAvailable: Bool = false,
        headingText: String = "—",
        cardinalDirectionText: String = "—",
        headingSourceText: String? = nil,
        altitudeText: String? = nil,
        altimeter: DashboardAltitudeViewData = .init(),
        latitudeText: String? = nil,
        longitudeText: String? = nil,
        canCalibrate: Bool = false
    ) {
        self.status = status
        self.leanDegrees = leanDegrees
        self.leanText = leanText
        self.leanDirectionText = leanDirectionText
            ?? rideDashboardLocalized(.rideDashboardDynamicsDirectionLevel)
        self.maximumLeftLeanText = maximumLeftLeanText
        self.maximumRightLeanText = maximumRightLeanText
        self.pitchDegrees = pitchDegrees
        self.pitchText = pitchText
        self.pitchDirectionText = pitchDirectionText
            ?? rideDashboardLocalized(.rideDashboardDynamicsDirectionLevel)
        self.maximumUphillPitchText = maximumUphillPitchText
        self.maximumDownhillPitchText = maximumDownhillPitchText
        self.headingDegrees = headingDegrees
        self.isHeadingAvailable = isHeadingAvailable
        self.headingText = headingText
        self.cardinalDirectionText = cardinalDirectionText
        self.headingSourceText = headingSourceText
            ?? rideDashboardLocalized(.rideDashboardDynamicsCourseUnavailable)
        self.altitudeText = altitudeText
        self.altimeter = altimeter
        self.latitudeText = latitudeText
        self.longitudeText = longitudeText
        self.canCalibrate = canCalibrate
    }
}

extension DashboardRideDynamicsViewData {
    func withCalibrationEnabled(_ isEnabled: Bool, altimeter: DashboardAltitudeViewData? = nil) -> Self {
        .init(
            status: status,
            leanDegrees: leanDegrees,
            leanText: leanText,
            leanDirectionText: leanDirectionText,
            maximumLeftLeanText: maximumLeftLeanText,
            maximumRightLeanText: maximumRightLeanText,
            pitchDegrees: pitchDegrees,
            pitchText: pitchText,
            pitchDirectionText: pitchDirectionText,
            maximumUphillPitchText: maximumUphillPitchText,
            maximumDownhillPitchText: maximumDownhillPitchText,
            headingDegrees: headingDegrees,
            isHeadingAvailable: isHeadingAvailable,
            headingText: headingText,
            cardinalDirectionText: cardinalDirectionText,
            headingSourceText: headingSourceText,
            altitudeText: altitudeText,
            altimeter: altimeter ?? self.altimeter,
            latitudeText: latitudeText,
            longitudeText: longitudeText,
            canCalibrate: canCalibrate && isEnabled
        )
    }
}
