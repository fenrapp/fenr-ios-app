import EnvironmentDomain
import Foundation
@testable import RideNavigationData
import RideNavigationDomain

enum RideNavigationDataFixtures {
    static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000.125)
    static let laterDate = Date(timeIntervalSince1970: 1_700_000_100.875)
    static let routeID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    static let segmentID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
    static let point = RideRoutePoint(
        coordinate: GeographicCoordinate(latitudeDegrees: 41, longitudeDegrees: 2)!,
        elevationMeters: 100,
        timestamp: referenceDate,
        horizontalAccuracyMeters: 5
    )

    static func makeRoute(
        id: UUID = routeID,
        name: String = "Forest & Coast",
        createdAt: Date = referenceDate,
        updatedAt: Date? = nil,
        segments: [RideRouteSegment]? = nil
    ) -> RideRoute {
        RideRoute(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            segments: segments ?? [RideRouteSegment(id: segmentID, points: [point])]
        )
    }

    static func makeParser(
        now: @escaping @Sendable () -> Date = { laterDate },
        limits: GPXRouteImportLimits = .init(
            maximumFileSizeBytes: 1_000_000,
            maximumPointCount: 10_000
        )
    ) -> GPXRouteParser {
        GPXRouteParser(
            now: now,
            dateFormat: .init(includingFractionalSeconds: true),
            fallbackDateFormat: .init(),
            limits: limits
        )
    }
}
