import EnvironmentDomain
import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationPlanningController {
    func resolveExternalLink(_ url: URL) {
        let token = begin(.externalLink)
        let resolver = planning.externalMapLinkResolver
        externalLinkTask = Task { [weak self] in
            do {
                let destination = try await resolver.destination(from: url)
                try Task.checkCancellation()
                guard let self, isCurrent(token) else { return }
                externalLinkTask = nil
                snapshot.pendingExternalDestination = destination
                publish(effect: .externalDestinationResolved, token: token)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self, isCurrent(token) else { return }
                externalLinkTask = nil
                snapshot.errorMessage = String(localized: .rideNavigationMapLinkNoDestination)
                publish(token: token)
            }
        }
    }

    func holdExternalDestination(_ destination: NavigationPlace) {
        snapshot.pendingExternalDestination = destination
        publish()
    }

    @discardableResult
    func consumePendingDestination() -> NavigationPlace? {
        let destination = snapshot.pendingExternalDestination
        snapshot.pendingExternalDestination = nil
        publish()
        return destination
    }

    func findTrailExit(from origin: GeographicCoordinate, preferences: RoadRoutePreferences) {
        guard snapshot.selectedRoute != nil else { return }
        let token = begin(.trailExit)
        snapshot.isFindingTrailExit = true
        snapshot.errorMessage = nil
        publish()
        let finder = planning.trailExitFinder
        trailExitTask = Task { [weak self] in
            do {
                let exit = try await finder.findExit(from: origin, preferences: preferences)
                try Task.checkCancellation()
                guard let self, isCurrent(token) else { return }
                trailExitTask = nil
                snapshot.setTrailExit(exit)
                snapshot.isFindingTrailExit = false
                publish(effect: .trailExitReady, token: token)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self, isCurrent(token) else { return }
                trailExitTask = nil
                snapshot.isFindingTrailExit = false
                snapshot.errorMessage = String(localized: .rideNavigationNoRoadExitFound)
                publish(token: token)
            }
        }
    }

    func cancelTrailExitPreview() {
        cancel(.trailExit)
        snapshot.setTrailExit(nil)
        publish()
    }

    func selectTrailExit() -> Bool {
        guard let exit = snapshot.trailExitPreview else { return false }
        cancel(.road)
        cancel(.trailExit)
        snapshot.setRoadRoute(exit.route)
        snapshot.roadRoutes = [exit.route]
        snapshot.selectedRoadRouteIndex = 0
        snapshot.selectedDestination = exit.destination
        snapshot.roadNavigationPurpose = .trailExit
        snapshot.setTrailExit(nil)
        snapshot.errorMessage = nil
        publish()
        return true
    }
}
