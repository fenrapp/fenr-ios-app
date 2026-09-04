import EnvironmentDomain
import RideNavigationDomain

public struct RideNavigationMapPresentationMapper: Sendable {
    struct TrailOverlayInput: Sendable {
        let hasSelectedRoute: Bool
        let activity: RideNavigationViewState.Activity
        let isPresentingTrailExit: Bool
        let trailMap: RideNavigationTrailMapController.PresentationSnapshot
        let guidancePlan: RideRouteGuidancePlan?
        let guidance: RideRouteGuidanceSnapshot?
    }

    struct TrailOverlay: Equatable, Sendable {
        let polylines: [NavigationMapPolyline]
        let markers: [NavigationMapMarker]
        let directionalIndicators: [NavigationMapDirectionalIndicator]

        static let empty = TrailOverlay(
            polylines: [],
            markers: [],
            directionalIndicators: []
        )
    }

    public init() {}

    func coordinate(_ coordinate: GeographicCoordinate) -> NavigationMapCoordinate {
        // GeographicCoordinate has already validated these values at the domain boundary.
        NavigationMapCoordinate(
            latitudeDegrees: coordinate.latitudeDegrees,
            longitudeDegrees: coordinate.longitudeDegrees
        )!
    }

    func coordinates(_ coordinates: [GeographicCoordinate]) -> [NavigationMapCoordinate] {
        coordinates.map(coordinate)
    }

    func trailOverlay(_ input: TrailOverlayInput) -> TrailOverlay {
        guard input.hasSelectedRoute else { return .empty }
        let routeRole: NavigationMapPolylineRole = input.isPresentingTrailExit
            ? .completed : .planned
        var polylines: [NavigationMapPolyline] = []
        var markers: [NavigationMapMarker] = []
        var directionalIndicators: [NavigationMapDirectionalIndicator] = []

        if input.activity == .following,
           !input.isPresentingTrailExit,
           let guidance = input.guidance {
            appendCachedRoute(
                input.trailMap,
                role: .trailFuture,
                to: &polylines
            )
            polylines.append(contentsOf: input.trailMap.completedPolylines)
            appendGuidanceSlices(
                guidance.activeCorridorSlices,
                trailMapRevision: input.trailMap.revision,
                to: &polylines
            )
        } else {
            appendCachedRoute(input.trailMap, role: routeRole, to: &polylines)

        }

        if input.activity == .following, let guidance = input.guidance {
            directionalIndicators = guidance.directionalIndicators.map {
                NavigationMapDirectionalIndicator(
                    id: $0.id,
                    coordinate: coordinate($0.coordinate),
                    rotationDegrees: $0.bearingDegrees
                )
            }
        } else if input.activity == .preview, let plan = input.guidancePlan {
            directionalIndicators = previewIndicators(for: plan)
        }

        if input.activity == .preview, let start = input.trailMap.startCoordinate {
            markers.append(
                NavigationMapMarker(
                    id: "start",
                    coordinate: start,
                    title: String(localized: .rideNavigationMapMarkerStart),
                    role: .start
                )
            )
        }
        if let finish = input.trailMap.finishCoordinate {
            markers.append(
                NavigationMapMarker(
                    id: "finish",
                    coordinate: finish,
                    title: String(localized: .rideNavigationMapMarkerFinish),
                    role: .finish
                )
            )
        }
        return TrailOverlay(
            polylines: polylines,
            markers: markers,
            directionalIndicators: directionalIndicators
        )
    }

    private func appendCachedRoute(
        _ trailMap: RideNavigationTrailMapController.PresentationSnapshot,
        role: NavigationMapPolylineRole,
        to polylines: inout [NavigationMapPolyline]
    ) {
        for (index, points) in trailMap.segments.enumerated() where points.count > 1 {
            polylines.append(
                NavigationMapPolyline(
                    id: "planned-\(index)",
                    points: points,
                    role: role,
                    revision: trailMap.revision
                )
            )
        }
    }

    private func appendGuidanceSlices(
        _ slices: [RideRouteGuidanceSlice],
        trailMapRevision: Int,
        to polylines: inout [NavigationMapPolyline]
    ) {
        for (index, slice) in slices.enumerated() where slice.coordinates.count > 1 {
            polylines.append(
                NavigationMapPolyline(
                    id: "trail-active-\(slice.segmentIndex)-\(index)",
                    points: coordinates(slice.coordinates),
                    role: .trailActive,
                    revision: guidanceSliceRevision(
                        slice,
                        trailMapRevision: trailMapRevision
                    )
                )
            )
        }
    }

    private func previewIndicators(
        for plan: RideRouteGuidancePlan
    ) -> [NavigationMapDirectionalIndicator] {
        let spacing = max(
            Constants.previewMinimumIndicatorSpacingMeters,
            plan.totalDistanceMeters / Double(Constants.maximumPreviewIndicators)
        )
        var indicators: [NavigationMapDirectionalIndicator] = []
        var distance = spacing
        while distance < plan.totalDistanceMeters,
              indicators.count < Constants.maximumPreviewIndicators {
            guard let coordinate = plan.coordinate(atDistanceMeters: distance),
                  let next = plan.coordinate(
                      atDistanceMeters: min(
                          distance + Constants.indicatorBearingLookAheadMeters,
                          plan.totalDistanceMeters
                      )
                  ) else { break }
            indicators.append(
                NavigationMapDirectionalIndicator(
                    id: "preview-\(Int(distance.rounded()))",
                    coordinate: self.coordinate(coordinate),
                    rotationDegrees: RideRouteGeometry.bearingDegrees(from: coordinate, to: next)
                )
            )
            distance += spacing
        }
        return indicators
    }

    private func guidanceSliceRevision(
        _ slice: RideRouteGuidanceSlice,
        trailMapRevision: Int
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(trailMapRevision)
        hasher.combine(slice.segmentIndex)
        hasher.combine(slice.distanceRange.lowerBoundMeters.bitPattern)
        hasher.combine(slice.distanceRange.upperBoundMeters.bitPattern)
        return hasher.finalize()
    }

    private enum Constants {
        static let maximumPreviewIndicators = 24
        static let previewMinimumIndicatorSpacingMeters = 250.0
        static let indicatorBearingLookAheadMeters = 5.0
    }
}
