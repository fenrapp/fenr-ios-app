import RideNavigationDomain

@MainActor
extension RideNavigationViewModel {
    func appendSelectedRoute(
        to polylines: inout [NavigationMapPolyline],
        markers: inout [NavigationMapMarker]
    ) {
        guard selectedRoute != nil else { return }
        let routeRole: NavigationMapPolylineRole = trailExitPreview != nil
            || roadNavigationPurpose == .trailExit ? .completed : .planned
        if activity == .following,
           trailExitPreview == nil,
           roadNavigationPurpose != .trailExit,
           let snapshot = trailGuidance.snapshot {
            appendCachedRoute(role: .trailFuture, to: &polylines)
            trailMap.appendCompletedPolylines(to: &polylines)
            appendGuidanceSlices(
                snapshot.activeCorridorSlices,
                idPrefix: "trail-active",
                role: .trailActive,
                to: &polylines
            )
        } else {
            appendCachedRoute(role: routeRole, to: &polylines)
        }
        if activity == .preview, let start = trailMap.startCoordinate {
            markers.append(
                .init(
                    id: "start",
                    coordinate: start,
                    title: "Start",
                    role: .start
                )
            )
        }
        if let finish = trailMap.finishCoordinate {
            markers.append(
                .init(
                    id: "finish",
                    coordinate: finish,
                    title: "Finish",
                    role: .finish
                )
            )
        }
    }

    private func appendCachedRoute(
        role: NavigationMapPolylineRole,
        to polylines: inout [NavigationMapPolyline]
    ) {
        for (index, points) in trailMap.routeSegments.enumerated() where points.count > 1 {
            polylines.append(
                NavigationMapPolyline(
                    id: "planned-\(index)",
                    points: points,
                    role: role,
                    revision: trailMap.routeRevision
                )
            )
        }
    }

    func appendDirectionalIndicators(
        to indicators: inout [NavigationMapDirectionalIndicator]
    ) {
        if activity == .following, let snapshot = trailGuidance.snapshot {
            indicators = snapshot.directionalIndicators.map {
                NavigationMapDirectionalIndicator(
                    id: $0.id,
                    coordinate: mapMapper.coordinate($0.coordinate),
                    rotationDegrees: $0.bearingDegrees
                )
            }
            return
        }
        guard activity == .preview, let plan = trailGuidance.plan else { return }
        let spacing = max(
            Constants.previewMinimumIndicatorSpacingMeters,
            plan.totalDistanceMeters / Double(Constants.maximumPreviewIndicators)
        )
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
                    coordinate: mapMapper.coordinate(coordinate),
                    rotationDegrees: RideRouteGeometry.bearingDegrees(from: coordinate, to: next)
                )
            )
            distance += spacing
        }
    }

    private func appendGuidanceSlices(
        _ slices: [RideRouteGuidanceSlice],
        idPrefix: String,
        role: NavigationMapPolylineRole,
        to polylines: inout [NavigationMapPolyline]
    ) {
        for (index, slice) in slices.enumerated() where slice.coordinates.count > 1 {
            polylines.append(
                NavigationMapPolyline(
                    id: "\(idPrefix)-\(slice.segmentIndex)-\(index)",
                    points: mapMapper.coordinates(slice.coordinates),
                    role: role,
                    revision: guidanceSliceRevision(slice)
                )
            )
        }
    }

    private func guidanceSliceRevision(_ slice: RideRouteGuidanceSlice) -> Int {
        var hasher = Hasher()
        hasher.combine(trailMap.routeRevision)
        hasher.combine(slice.segmentIndex)
        hasher.combine(slice.distanceRange.lowerBoundMeters.bitPattern)
        hasher.combine(slice.distanceRange.upperBoundMeters.bitPattern)
        return hasher.finalize()
    }
}
