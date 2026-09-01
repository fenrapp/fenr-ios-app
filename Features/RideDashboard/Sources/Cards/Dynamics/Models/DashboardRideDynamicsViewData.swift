public struct DashboardRideDynamicsViewData: Equatable, Sendable {
    public enum Status: String, Equatable, Sendable {
        case unavailable = "UNAVAILABLE"
        case calibrating = "CALIBRATING"
        case zeroing = "HOLD STILL"
        case live = "IMU BETA"
        case signalLost = "SIGNAL LOST"
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
    public let altitudeText: String?
    public let latitudeText: String?
    public let longitudeText: String?
    public let canCalibrate: Bool

    public init(
        status: Status = .unavailable,
        leanDegrees: Double = .zero,
        leanText: String = "—",
        leanDirectionText: String = "LEVEL",
        maximumLeftLeanText: String = "—",
        maximumRightLeanText: String = "—",
        pitchDegrees: Double = .zero,
        pitchText: String = "—",
        pitchDirectionText: String = "LEVEL",
        maximumUphillPitchText: String = "—",
        maximumDownhillPitchText: String = "—",
        headingDegrees: Double = .zero,
        isHeadingAvailable: Bool = false,
        headingText: String = "—",
        cardinalDirectionText: String = "—",
        headingSourceText: String = "NO COURSE",
        altitudeText: String? = nil,
        latitudeText: String? = nil,
        longitudeText: String? = nil,
        canCalibrate: Bool = false
    ) {
        self.status = status
        self.leanDegrees = leanDegrees
        self.leanText = leanText
        self.leanDirectionText = leanDirectionText
        self.maximumLeftLeanText = maximumLeftLeanText
        self.maximumRightLeanText = maximumRightLeanText
        self.pitchDegrees = pitchDegrees
        self.pitchText = pitchText
        self.pitchDirectionText = pitchDirectionText
        self.maximumUphillPitchText = maximumUphillPitchText
        self.maximumDownhillPitchText = maximumDownhillPitchText
        self.headingDegrees = headingDegrees
        self.isHeadingAvailable = isHeadingAvailable
        self.headingText = headingText
        self.cardinalDirectionText = cardinalDirectionText
        self.headingSourceText = headingSourceText
        self.altitudeText = altitudeText
        self.latitudeText = latitudeText
        self.longitudeText = longitudeText
        self.canCalibrate = canCalibrate
    }
}

extension DashboardRideDynamicsViewData {
    func withCalibrationEnabled(_ isEnabled: Bool) -> Self {
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
            latitudeText: latitudeText,
            longitudeText: longitudeText,
            canCalibrate: canCalibrate && isEnabled
        )
    }
}
