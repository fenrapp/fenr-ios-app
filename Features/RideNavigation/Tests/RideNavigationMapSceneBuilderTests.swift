import EnvironmentDomain
@testable import RideNavigation
import RideNavigationDomain
import SettingsDomain
import Testing

struct RideNavigationMapSceneBuilderTests {
    @Test("Maps all polyline roles into the five configurable appearance groups")
    func mapsPolylineRolesToAppearanceGroups() {
        let appearances = makeDistinctAppearances()
        let segment = RideRouteSegment(points: [
            RideRoutePoint(coordinate: coordinate(latitude: 41, longitude: 2)),
            RideRoutePoint(coordinate: coordinate(latitude: 41.001, longitude: 2.001))
        ])
        let roles = NavigationMapPolylineRole.allCasesForTesting
        let scene = RideNavigationMapSceneBuilder(
            mapper: RideNavigationMapPresentationMapper()
        ).makeScene(
            .init(
                source: .appleStandard,
                displayStyle: .map,
                camera: .automatic,
                userCoordinate: nil,
                userHeadingDegrees: nil,
                trailOverlay: .init(
                    hasSelectedRoute: false,
                    activity: .preview,
                    isPresentingTrailExit: false,
                    trailMap: RideNavigationTrailMapController.PresentationSnapshot(
                        segments: [],
                        startCoordinate: nil,
                        finishCoordinate: nil,
                        revision: 0,
                        completedPolylines: []
                    ),
                    guidancePlan: nil,
                    guidance: nil
                ),
                roadRoute: nil,
                roadRouteRevision: 0,
                destination: nil,
                trailExit: nil,
                trailExitRevision: 0,
                rejoinGuide: nil,
                traces: roles.map {
                    .init(idPrefix: $0.testName, role: $0, segments: [segment])
                },
                lineAppearances: appearances,
                showsCompassRing: true,
                showsRoadsInFocus: true
            )
        )

        #expect(scene.showsCompassRing)
        #expect(scene.showsRoadsInFocus)
        for line in scene.polylines {
            let expected = appearances[line.role.expectedGroup]
            #expect(line.appearance?.red == expected.color.red)
            #expect(line.appearance?.green == expected.color.green)
            #expect(line.appearance?.blue == expected.color.blue)
            #expect(line.appearance?.lineWidth == expectedLineWidth(expected.thickness))
        }
    }

    private func makeDistinctAppearances() -> RideNavigationLineAppearances {
        RideNavigationLineAppearances(
            pendingRoute: appearance(0.1, .thin),
            activeSection: appearance(0.2, .regular),
            completedRoute: appearance(0.3, .thick),
            recording: appearance(0.4, .thin),
            connector: appearance(0.5, .thick)
        )
    }

    private func appearance(
        _ red: Double,
        _ thickness: RideNavigationLineThickness
    ) -> RideNavigationLineAppearance {
        RideNavigationLineAppearance(
            color: RideNavigationLineColor(red: red, green: 0, blue: 0),
            thickness: thickness
        )
    }

    private func coordinate(latitude: Double, longitude: Double) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)!
    }

    private func expectedLineWidth(_ thickness: RideNavigationLineThickness) -> Double {
        switch thickness {
        case .thin: 4
        case .regular: 7
        case .thick: 10
        }
    }
}

private extension NavigationMapPolylineRole {
    static let allCasesForTesting: [Self] = [
        .planned,
        .trailActive,
        .trailCompleted,
        .trailFuture,
        .completed,
        .recorded,
        .approach,
        .rejoinGuide
    ]

    var testName: String { String(describing: self) }

    var expectedGroup: RideNavigationLineGroup {
        switch self {
        case .planned, .trailFuture: .pendingRoute
        case .trailActive: .activeSection
        case .trailCompleted, .completed: .completedRoute
        case .recorded: .recording
        case .approach, .rejoinGuide: .connector
        }
    }
}
