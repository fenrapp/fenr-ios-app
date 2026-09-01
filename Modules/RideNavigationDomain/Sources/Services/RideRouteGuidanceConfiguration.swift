import Foundation

public struct RideRouteGuidanceConfiguration: Equatable, Sendable {
    public let spatialCellSizeMeters: Double
    public let entryDistanceMeters: Double
    public let entryProjectionTieMeters: Double
    public let reliableHorizontalAccuracyMeters: Double
    public let reliableCourseAccuracyDegrees: Double
    public let reliableCourseSpeedKilometersPerHour: Double
    public let compatibleCourseDifferenceDegrees: Double
    public let continuityBacktrackMeters: Double
    public let continuityLookAheadMeters: Double
    public let activeCorridorMeters: Double
    public let indicatorSpacingMeters: Double
    public let maximumActiveIndicators: Int
    public let decisionLookAheadMeters: Double
    public let straightTurnThresholdDegrees: Double
    public let forkProximityMeters: Double
    public let forkDivergenceMeters: Double
    public let forkDivergenceLookAheadMeters: Double
    public let offRouteDistanceMeters: Double
    public let recoveryDistanceMeters: Double
    public let alternativeRouteDistanceMeters: Double
    public let wrongForkSampleCount: Int
    public let wrongForkConfirmationSeconds: TimeInterval
    public let wrongForkConfirmationDistanceMeters: Double
    public let rejoinConfirmationSeconds: TimeInterval
    public let rejoinConfirmationDistanceMeters: Double
    public let arrivalDistanceMeters: Double
    public let minimumArrivalAdvanceMeters: Double

    public init(
        spatialCellSizeMeters: Double = 75,
        entryDistanceMeters: Double = 50,
        entryProjectionTieMeters: Double = 8,
        reliableHorizontalAccuracyMeters: Double = 20,
        reliableCourseAccuracyDegrees: Double = 30,
        reliableCourseSpeedKilometersPerHour: Double = 5,
        compatibleCourseDifferenceDegrees: Double = 60,
        continuityBacktrackMeters: Double = 35,
        continuityLookAheadMeters: Double = 120,
        activeCorridorMeters: Double = 250,
        indicatorSpacingMeters: Double = 40,
        maximumActiveIndicators: Int = 7,
        decisionLookAheadMeters: Double = 150,
        straightTurnThresholdDegrees: Double = 25,
        forkProximityMeters: Double = 20,
        forkDivergenceMeters: Double = 30,
        forkDivergenceLookAheadMeters: Double = 60,
        offRouteDistanceMeters: Double = 50,
        recoveryDistanceMeters: Double = 30,
        alternativeRouteDistanceMeters: Double = 30,
        wrongForkSampleCount: Int = 3,
        wrongForkConfirmationSeconds: TimeInterval = 4,
        wrongForkConfirmationDistanceMeters: Double = 20,
        rejoinConfirmationSeconds: TimeInterval = 10,
        rejoinConfirmationDistanceMeters: Double = 100,
        arrivalDistanceMeters: Double = 30,
        minimumArrivalAdvanceMeters: Double = 50
    ) {
        self.spatialCellSizeMeters = max(spatialCellSizeMeters, 10)
        self.entryDistanceMeters = max(entryDistanceMeters, .zero)
        self.entryProjectionTieMeters = max(entryProjectionTieMeters, .zero)
        self.reliableHorizontalAccuracyMeters = max(reliableHorizontalAccuracyMeters, .zero)
        self.reliableCourseAccuracyDegrees = max(reliableCourseAccuracyDegrees, .zero)
        self.reliableCourseSpeedKilometersPerHour = max(reliableCourseSpeedKilometersPerHour, .zero)
        self.compatibleCourseDifferenceDegrees = max(compatibleCourseDifferenceDegrees, .zero)
        self.continuityBacktrackMeters = max(continuityBacktrackMeters, .zero)
        self.continuityLookAheadMeters = max(continuityLookAheadMeters, .zero)
        self.activeCorridorMeters = max(activeCorridorMeters, .zero)
        self.indicatorSpacingMeters = max(indicatorSpacingMeters, 1)
        self.maximumActiveIndicators = max(maximumActiveIndicators, 1)
        self.decisionLookAheadMeters = max(decisionLookAheadMeters, .zero)
        self.straightTurnThresholdDegrees = max(straightTurnThresholdDegrees, .zero)
        self.forkProximityMeters = max(forkProximityMeters, .zero)
        self.forkDivergenceMeters = max(forkDivergenceMeters, .zero)
        self.forkDivergenceLookAheadMeters = max(forkDivergenceLookAheadMeters, .zero)
        self.offRouteDistanceMeters = max(offRouteDistanceMeters, .zero)
        self.recoveryDistanceMeters = max(recoveryDistanceMeters, .zero)
        self.alternativeRouteDistanceMeters = max(alternativeRouteDistanceMeters, .zero)
        self.wrongForkSampleCount = max(wrongForkSampleCount, 1)
        self.wrongForkConfirmationSeconds = max(wrongForkConfirmationSeconds, .zero)
        self.wrongForkConfirmationDistanceMeters = max(wrongForkConfirmationDistanceMeters, .zero)
        self.rejoinConfirmationSeconds = max(rejoinConfirmationSeconds, .zero)
        self.rejoinConfirmationDistanceMeters = max(rejoinConfirmationDistanceMeters, .zero)
        self.arrivalDistanceMeters = max(arrivalDistanceMeters, .zero)
        self.minimumArrivalAdvanceMeters = max(minimumArrivalAdvanceMeters, .zero)
    }

    public static let standard = Self()
}
