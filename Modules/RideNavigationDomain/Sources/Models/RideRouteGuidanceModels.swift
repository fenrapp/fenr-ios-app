import EnvironmentDomain
import Foundation

public struct RideRoutePathPosition: Equatable, Sendable {
    public let segmentIndex: Int
    public let edgeIndex: Int
    public let fraction: Double
    public let distanceAlongRouteMeters: Double

    public init(
        segmentIndex: Int,
        edgeIndex: Int,
        fraction: Double,
        distanceAlongRouteMeters: Double
    ) {
        self.segmentIndex = segmentIndex
        self.edgeIndex = edgeIndex
        self.fraction = fraction
        self.distanceAlongRouteMeters = distanceAlongRouteMeters
    }
}

public struct RideRouteProjection: Equatable, Sendable {
    public enum Confidence: Equatable, Sendable {
        case high
        case medium
        case low
    }

    public let coordinate: GeographicCoordinate
    public let position: RideRoutePathPosition
    public let distanceFromRouteMeters: Double
    public let localBearingDegrees: Double
    public let confidence: Confidence

    public init(
        coordinate: GeographicCoordinate,
        position: RideRoutePathPosition,
        distanceFromRouteMeters: Double,
        localBearingDegrees: Double,
        confidence: Confidence
    ) {
        self.coordinate = coordinate
        self.position = position
        self.distanceFromRouteMeters = distanceFromRouteMeters
        self.localBearingDegrees = localBearingDegrees
        self.confidence = confidence
    }
}

public enum RideRouteEntryClassification: Equatable, Sendable {
    case forward
    case reverse
    case ambiguous
}

public struct RideRouteEntryMatch: Equatable, Sendable {
    public let classification: RideRouteEntryClassification
    public let selectedProjection: RideRouteProjection?
    public let projections: [RideRouteProjection]

    public init(
        classification: RideRouteEntryClassification,
        selectedProjection: RideRouteProjection?,
        projections: [RideRouteProjection]
    ) {
        self.classification = classification
        self.selectedProjection = selectedProjection
        self.projections = projections
    }
}

public struct RideRouteDistanceRange: Equatable, Sendable {
    public let lowerBoundMeters: Double
    public let upperBoundMeters: Double

    public init(lowerBoundMeters: Double, upperBoundMeters: Double) {
        self.lowerBoundMeters = lowerBoundMeters
        self.upperBoundMeters = max(upperBoundMeters, lowerBoundMeters)
    }
}

public struct RideRouteGuidanceSegmentRange: Equatable, Sendable {
    public let segmentIndex: Int
    public let distanceRange: RideRouteDistanceRange

    public init(segmentIndex: Int, distanceRange: RideRouteDistanceRange) {
        self.segmentIndex = segmentIndex
        self.distanceRange = distanceRange
    }
}

public struct RideRouteGuidanceSlice: Equatable, Sendable {
    public let segmentIndex: Int
    public let distanceRange: RideRouteDistanceRange
    public let coordinates: [GeographicCoordinate]

    public init(
        segmentIndex: Int,
        distanceRange: RideRouteDistanceRange,
        coordinates: [GeographicCoordinate]
    ) {
        self.segmentIndex = segmentIndex
        self.distanceRange = distanceRange
        self.coordinates = coordinates
    }
}

public struct RideRouteGuidanceIndicator: Equatable, Identifiable, Sendable {
    public let id: String
    public let coordinate: GeographicCoordinate
    public let bearingDegrees: Double

    public init(id: String, coordinate: GeographicCoordinate, bearingDegrees: Double) {
        self.id = id
        self.coordinate = coordinate
        self.bearingDegrees = bearingDegrees
    }
}

public enum RideRouteGuidanceTurnDirection: Equatable, Sendable {
    case left
    case right
    case straight
}

public struct RideRouteGuidanceDecision: Equatable, Sendable {
    public let direction: RideRouteGuidanceTurnDirection
    public let coordinate: GeographicCoordinate
    public let distanceMeters: Double
    public let isFork: Bool
    public let identifier: String

    public init(
        direction: RideRouteGuidanceTurnDirection,
        coordinate: GeographicCoordinate,
        distanceMeters: Double,
        isFork: Bool,
        identifier: String
    ) {
        self.direction = direction
        self.coordinate = coordinate
        self.distanceMeters = distanceMeters
        self.isFork = isFork
        self.identifier = identifier
    }
}

public enum RideRouteGuidanceRouteState: Equatable, Sendable {
    case onRoute
    case offRoute
    case wrongFork
    case rejoined
}

public struct RideRouteGuidanceSample: Equatable, Sendable {
    public let coordinate: GeographicCoordinate
    public let horizontalAccuracyMeters: Double?
    public let courseDegrees: Double?
    public let courseAccuracyDegrees: Double?
    public let speedKilometersPerHour: Double
    public let observedAt: Date

    public init(
        coordinate: GeographicCoordinate,
        horizontalAccuracyMeters: Double?,
        courseDegrees: Double?,
        courseAccuracyDegrees: Double?,
        speedKilometersPerHour: Double,
        observedAt: Date
    ) {
        self.coordinate = coordinate
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.courseDegrees = courseDegrees
        self.courseAccuracyDegrees = courseAccuracyDegrees
        self.speedKilometersPerHour = speedKilometersPerHour
        self.observedAt = observedAt
    }
}

public struct RideRouteGuidanceSnapshot: Equatable, Sendable {
    public let projection: RideRouteProjection
    public let completedRange: RideRouteDistanceRange
    public let activeCorridorRange: RideRouteDistanceRange
    public let futureRange: RideRouteDistanceRange
    public let activeCorridorSlices: [RideRouteGuidanceSlice]
    public let directionalIndicators: [RideRouteGuidanceIndicator]
    public let decision: RideRouteGuidanceDecision?
    public let routeState: RideRouteGuidanceRouteState
    public let hasReachedFinish: Bool

    public init(
        projection: RideRouteProjection,
        completedRange: RideRouteDistanceRange,
        activeCorridorRange: RideRouteDistanceRange,
        futureRange: RideRouteDistanceRange,
        activeCorridorSlices: [RideRouteGuidanceSlice],
        directionalIndicators: [RideRouteGuidanceIndicator],
        decision: RideRouteGuidanceDecision?,
        routeState: RideRouteGuidanceRouteState,
        hasReachedFinish: Bool
    ) {
        self.projection = projection
        self.completedRange = completedRange
        self.activeCorridorRange = activeCorridorRange
        self.futureRange = futureRange
        self.activeCorridorSlices = activeCorridorSlices
        self.directionalIndicators = directionalIndicators
        self.decision = decision
        self.routeState = routeState
        self.hasReachedFinish = hasReachedFinish
    }
}
