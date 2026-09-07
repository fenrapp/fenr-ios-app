import EnvironmentDomain
import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationPlanningController {
    enum RoadRequest {
        case preview(showsSearchLoading: Bool)
        case refreshPreview
        case reroute
        case approach

        var effect: RideNavigationPlanningUpdate.Effect {
            switch self {
            case .preview: .previewReady
            case .refreshPreview: .previewUpdated
            case .reroute: .rerouteReady
            case .approach: .approachReady
            }
        }

        var errorMessage: String {
            switch self {
            case .preview: String(localized: .rideNavigationRouteCalculationError)
            case .refreshPreview: String(localized: .rideNavigationPreferencesUpdateError)
            case .reroute: String(localized: .rideNavigationReroutingUnavailable)
            case .approach: String(localized: .rideNavigationApproachCalculationError)
            }
        }
    }

    func preview(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        preferences: RoadRoutePreferences,
        showsSearchLoading: Bool
    ) {
        contextGeneration &+= 1
        cancelOperations()
        previewPresentationPending = true
        requestRoadRoutes(
            from: origin, to: destination, preferences: preferences,
            request: .preview(showsSearchLoading: showsSearchLoading)
        )
    }

    func recalculatePreview(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        preferences: RoadRoutePreferences
    ) {
        requestRoadRoutes(from: origin, to: destination, preferences: preferences, request: .refreshPreview)
    }

    func reroute(from origin: GeographicCoordinate, preferences: RoadRoutePreferences) {
        let date = timing.now()
        if let lastRoadRerouteAt,
           date.timeIntervalSince(lastRoadRerouteAt) < Constants.minimumRerouteIntervalSeconds { return }
        guard let destination = snapshot.selectedDestination else { return }
        lastRoadRerouteAt = date
        requestRoadRoutes(from: origin, to: destination, preferences: preferences, request: .reroute)
    }

    func approach(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        preferences: RoadRoutePreferences
    ) {
        requestRoadRoutes(from: origin, to: destination, preferences: preferences, request: .approach)
    }

    func selectRoadOption(_ index: Int) -> Bool {
        guard snapshot.roadRoutes.indices.contains(index) else { return false }
        cancel(.road)
        snapshot.selectedRoadRouteIndex = index
        snapshot.setRoadRoute(snapshot.roadRoutes[index])
        publish()
        return true
    }

    func prepareExternalDestination(_ destination: NavigationPlace) {
        resetPlan()
        snapshot.selectedDestination = destination
        snapshot.roadNavigationPurpose = .destination
        publish()
    }

    private func requestRoadRoutes(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        preferences: RoadRoutePreferences,
        request: RoadRequest
    ) {
        let token = begin(.road)
        roadRequest = request
        snapshot.errorMessage = nil
        switch request {
        case let .preview(showsSearchLoading):
            snapshot.roadRoutes = []
            snapshot.selectedRoadRouteIndex = 0
            snapshot.isPreviewSearchLoading = showsSearchLoading
            snapshot.isCalculatingRoadRoutes = true
        case .refreshPreview: snapshot.isCalculatingRoadRoutes = true
        case .reroute: snapshot.isRerouting = true
        case .approach:
            snapshot.roadRoutes = []
            snapshot.selectedRoadRouteIndex = 0
        }
        publish()
        let calculator = planning.roadRouteCalculator
        routeTask = Task { [weak self] in
            do {
                let routes: [RoadNavigationRoute]
                switch request {
                case .preview, .refreshPreview:
                    routes = try await calculator.routes(from: origin, to: destination, preferences: preferences)
                case .reroute, .approach:
                    routes = [try await calculator.route(from: origin, to: destination, preferences: preferences)]
                }
                try Task.checkCancellation()
                guard let self, isCurrent(token) else { return }
                guard let first = routes.first else { throw RoadRouteCalculationError.routeUnavailable }
                routeTask = nil
                snapshot.roadRoutes = routes
                snapshot.selectedRoadRouteIndex = 0
                snapshot.setRoadRoute(first)
                snapshot.selectedDestination = destination
                switch request {
                case .preview:
                    snapshot.selectedRoute = nil
                    snapshot.roadNavigationPurpose = .destination
                    snapshot.setTrailExit(nil)
                case .approach: snapshot.roadNavigationPurpose = .trailApproach
                case .reroute, .refreshPreview: break
                }
                finishRoadRequest()
                let effect: RideNavigationPlanningUpdate.Effect
                if case .refreshPreview = request, previewPresentationPending {
                    effect = .previewReady
                } else {
                    effect = request.effect
                }
                publish(effect: effect, token: token)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self, isCurrent(token) else { return }
                routeTask = nil
                finishRoadRequest()
                snapshot.errorMessage = request.errorMessage
                publish(token: token)
            }
        }
    }

    private func finishRoadRequest() {
        snapshot.isPreviewSearchLoading = false
        snapshot.isCalculatingRoadRoutes = false
        snapshot.isRerouting = false
    }
}
