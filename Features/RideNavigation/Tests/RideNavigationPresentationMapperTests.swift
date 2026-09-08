import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain
import SettingsDomain
import Testing

struct RideNavigationPresentationMapperTests {
    @Test("map coordinates copy validated domain values")
    func mapCoordinateCopiesValidatedDomainValues() throws {
        let domain = try #require(
            GeographicCoordinate(latitudeDegrees: 41.3851, longitudeDegrees: 2.1734)
        )

        let coordinate = RideNavigationMapPresentationMapper().coordinate(domain)

        #expect(coordinate.latitudeDegrees == 41.3851)
        #expect(coordinate.longitudeDegrees == 2.1734)
    }

    @Test("speed and distance honor resolved metric and US units")
    func speedAndDistanceRespectResolvedMetricAndUSUnits() {
        let metric = RideNavigationPresentationMapper(locale: Locale(identifier: "en_GB"))
        let imperialMapper = RideNavigationPresentationMapper(locale: Locale(identifier: "en_US"))

        #expect(metric.speed(kilometersPerHour: 100, measurementSystem: .metric) == ("100", "km/h"))
        #expect(metric.distance(meters: 1_000, measurementSystem: .metric) == "1.0 km")
        #expect(imperialMapper.speed(kilometersPerHour: 100, measurementSystem: .imperial) == ("62", "mph"))
        #expect(imperialMapper.distance(meters: 1_609.344, measurementSystem: .imperial) == "1.0 mi")
    }

    @Test("elapsed and travel time preserve zero and hour boundaries")
    func elapsedAndTravelTimePreserveZeroAndHourBoundaries() {
        let mapper = RideNavigationPresentationMapper(locale: Locale(identifier: "en_US"))
        let origin = coordinate(latitude: 41, longitude: 2)
        let destination = coordinate(latitude: 41.01, longitude: 2.01)

        #expect(mapper.elapsed(0) == "00:00")
        #expect(mapper.elapsed(3_599) == "59:59")
        #expect(mapper.elapsed(3_600) == "1:00:00")

        let zero = mapper.roadRouteOption(
            RoadNavigationRoute(
                name: "Zero",
                points: [origin, destination],
                distanceMeters: 1_000,
                expectedTravelTime: 0,
                steps: []
            ),
            index: 0,
            isSelected: true,
            measurementSystem: .metric
        )
        let hour = mapper.roadRouteOption(
            RoadNavigationRoute(
                name: "Hour",
                points: [origin, destination],
                distanceMeters: 1_000,
                expectedTravelTime: 3_600,
                steps: []
            ),
            index: 0,
            isSelected: true,
            measurementSystem: .metric
        )

        #expect(zero.detail.hasPrefix("1 min"))
        #expect(hour.detail.hasPrefix("1 hr"))
    }

    @Test("altitude respects units and rejects unavailable GPS samples")
    func altitudeRespectsUnitsAndValidity() {
        let mapper = RideNavigationPresentationMapper(locale: Locale(identifier: "en_US"))
        let metric = mapper.altitude(
            meters: 1_000,
            verticalAccuracyMeters: 8,
            measurementSystem: .metric
        )
        let imperial = mapper.altitude(
            meters: 1_000,
            verticalAccuracyMeters: 8,
            measurementSystem: .imperial
        )

        #expect(metric?.0 == "1,000")
        #expect(metric?.1 == "m")
        #expect(imperial?.0 == "3,281")
        #expect(imperial?.1 == "ft")
        #expect(mapper.altitude(meters: nil, verticalAccuracyMeters: 8, measurementSystem: .metric) == nil)
        #expect(
            mapper.altitude(
                meters: 1_000,
                verticalAccuracyMeters: -1,
                measurementSystem: .metric
            ) == nil
        )
    }

    @Test("GPX progress clamps to a localized whole percentage")
    func progressClampsToPercentageRange() {
        let mapper = RideNavigationPresentationMapper(locale: Locale(identifier: "en_US"))

        #expect(mapper.progress(-0.2) == "0%")
        #expect(mapper.progress(0.5) == "50%")
        #expect(mapper.progress(1.4) == "100%")
        #expect(mapper.progress(.nan) == nil)
    }

    @Test("route detail uses injected locale and the system date style")
    func routeDetailUsesInjectedLocaleAndSystemDateStyle() {
        let locale = Locale(identifier: "es_ES")
        let mapper = RideNavigationPresentationMapper(locale: locale)
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let route = RideRoute(
            name: "Ruta",
            createdAt: updatedAt,
            segments: [
                RideRouteSegment(points: [
                    RideRoutePoint(coordinate: coordinate(latitude: 41, longitude: 2))
                ])
            ]
        )
        let dateText = updatedAt.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale)
        )

        #expect(mapper.routeDetail(RideRouteSummary(route), measurementSystem: .metric) == "0,0 km · \(dateText)")
    }

    @Test("Fork directions map to the matching symbol and selected distance units", arguments: [
        (RideRouteGuidanceTurnDirection.left, "arrow.turn.up.left"),
        (.right, "arrow.turn.up.right"),
        (.straight, "arrow.up")
    ])
    func mapsForkDirections(direction: RideRouteGuidanceTurnDirection, symbol: String) throws {
        let mapper = RideNavigationPresentationMapper(locale: Locale(identifier: "en_US"))
        let decision = RideRouteGuidanceDecision(
            direction: direction,
            coordinate: coordinate(latitude: 41, longitude: 2),
            distanceMeters: 1_609.344,
            isFork: true,
            identifier: "fork"
        )

        let guidance = try #require(mapper.forkGuidance(
            routeState: .onRoute,
            decision: decision,
            measurementSystem: .imperial
        ))

        #expect(guidance.systemImage == symbol)
        #expect(guidance.distanceText == "1.0 mi")
    }

    @Test("Wrong-fork recovery overrides the next directional instruction")
    func wrongForkOverridesDecision() throws {
        let mapper = RideNavigationPresentationMapper(locale: Locale(identifier: "en_US"))
        let guidance = try #require(mapper.forkGuidance(
            routeState: .wrongFork,
            decision: .init(
                direction: .left,
                coordinate: coordinate(latitude: 41, longitude: 2),
                distanceMeters: 100,
                isFork: true,
                identifier: "fork"
            ),
            measurementSystem: .metric
        ))

        #expect(guidance.emphasis == .warning)
        #expect(guidance.systemImage == "arrow.uturn.backward")
    }

    @Test("Absent fork decisions produce no directional card")
    func omitsMissingFork() {
        let mapper = RideNavigationPresentationMapper(locale: Locale(identifier: "en_US"))

        #expect(mapper.forkGuidance(routeState: nil, decision: nil, measurementSystem: .metric) == nil)
        #expect(mapper.forkGuidance(routeState: .onRoute, decision: nil, measurementSystem: .metric) == nil)
    }

    private func coordinate(latitude: Double, longitude: Double) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)!
    }
}
