import EnvironmentDomain
import Foundation
import RideNavigationDomain
@MainActor
extension RideNavigationViewModel {
    public func updateSearchQuery(_ value: String) {
        searchQuery = value
        searchTask?.cancel()
        let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
        errorText = nil
        guard query.count >= Constants.minimumSearchCharacters else {
            searchResults = []
            render(isSearching: false)
            return
        }
        render(isSearching: true)
        startSearch(query, debounce: true)
    }
    public func search() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= Constants.minimumSearchCharacters else { return }
        searchTask?.cancel()
        render(isSearching: true)
        startSearch(query, debounce: false)
    }
    public func selectSearchResult(id: UUID) {
        guard let destination = searchResults.first(where: { $0.id == id }),
              let origin = locationSnapshot.coordinate else {
            errorText = String(localized: .rideNavigationCurrentLocationRequired)
            render()
            return
        }
        calculateRoadPreview(from: origin, to: destination, showsSearchLoading: true)
    }

    public func findTrailExit() {
        guard activity == .following,
              selectedRoute != nil,
              let origin = locationSnapshot.coordinate else {
            errorText = String(localized: .rideNavigationCurrentLocationRequiredForExit)
            render()
            return
        }
        let generation = operations.begin(.trailExit)
        let lifecycle = operations.lifecycleGeneration
        isFindingTrailExit = true
        errorText = nil
        render()
        let trailExitFinder = trailExitFinder
        let preferences = roadRoutePreferences
        trailExitTask = Task { [weak self] in
            do {
                let result = try await trailExitFinder.findExit(from: origin, preferences: preferences)
                try Task.checkCancellation()
                guard let self,
                      operations.isCurrent(.trailExit, generation: generation, lifecycle: lifecycle),
                      isStarted,
                      activity == .following else { return }
                trailExitPreview = result
                isFindingTrailExit = false
                cameraMode = .overview(
                    trailMap.overviewCoordinates + mapMapper.coordinates(result.route.points)
                )
                render()
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      operations.isCurrent(.trailExit, generation: generation, lifecycle: lifecycle),
                      isStarted else { return }
                isFindingTrailExit = false
                errorText = String(localized: .rideNavigationNoRoadExitFound)
                render()
            }
        }
    }
    public func cancelTrailExitPreview() {
        trailExitTask?.cancel()
        trailExitPreview = nil
        isFindingTrailExit = false
        cameraMode = followCamera
        render()
    }
    public func startTrailExit() {
        guard activity == .following, let exit = trailExitPreview else { return }
        roadRoute = exit.route
        roadRoutes = [exit.route]
        selectedRoadRouteIndex = .zero
        selectedDestination = exit.destination
        roadNavigationPurpose = .trailExit
        trailExitPreview = nil
        resetRoadStepGuidance()
        activity = .navigating
        applyPreferredMapStyleForActiveNavigation()
        cameraMode = followCamera
        errorText = nil
        render()
        announce(String(localized: .rideNavigationAnnouncementExitStarted))
    }
    public func resumeGPX() {
        guard activity == .navigating,
              roadNavigationPurpose == .trailExit,
              selectedRoute != nil else { return }
        routeTask?.cancel()
        roadRoute = nil
        roadRoutes = []
        selectedDestination = nil
        roadNavigationPurpose = nil
        resetRoadStepGuidance()
        activity = .following
        trailProgress = nil
        didAnnounceOffRoute = false
        if !trailGuidance.snapshot.hasActiveSession {
            trailGuidance.startSession(at: nil)
        }
        if let sample = trailGuidanceSample {
            updateTrailGuidance(with: sample)
        }
        cameraMode = followCamera
        errorText = nil
        render()
        announce(String(localized: .rideNavigationAnnouncementEnduroResumed))
    }

    func calculateRoadPreview(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        showsSearchLoading: Bool
    ) {
        roadRoutes = []
        selectedRoadRouteIndex = .zero
        let generation = operations.begin(.route)
        let lifecycle = operations.lifecycleGeneration
        isCalculatingRoadRoutes = true
        render(isSearching: showsSearchLoading)
        let roadRouteCalculator = roadRouteCalculator
        let preferences = roadRoutePreferences
        routeTask = Task { [weak self] in
            do {
                let calculatedRoutes = try await roadRouteCalculator.routes(
                    from: origin,
                    to: destination,
                    preferences: preferences
                )
                try Task.checkCancellation()
                guard let self,
                      operations.isCurrent(.route, generation: generation, lifecycle: lifecycle),
                      isStarted else { return }
                guard let firstRoute = calculatedRoutes.first else {
                    throw RoadRouteCalculationError.routeUnavailable
                }
                roadRoutes = calculatedRoutes
                selectedRoadRouteIndex = .zero
                roadRoute = firstRoute
                roadNavigationPurpose = .destination
                trailExitPreview = nil
                resetRoadStepGuidance()
                selectedDestination = destination
                selectedRoute = nil
                trailMap.reset()
                trailProgress = nil
                screen = .map
                activity = .preview
                mapDisplayStyle = .map
                cameraMode = .overview(mapMapper.coordinates(roadRoute?.points ?? []))
                errorText = nil
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      operations.isCurrent(.route, generation: generation, lifecycle: lifecycle),
                      isStarted else { return }
                errorText = String(localized: .rideNavigationRouteCalculationError)
            }
            guard let self,
                  operations.isCurrent(.route, generation: generation, lifecycle: lifecycle),
                  isStarted else { return }
            isCalculatingRoadRoutes = false
            render(isSearching: false)
        }
    }

    public func selectRoadRouteOption(_ index: Int) {
        guard roadRoutes.indices.contains(index) else { return }
        selectedRoadRouteIndex = index
        roadRoute = roadRoutes[index]
        resetRoadStepGuidance()
        cameraMode = .overview(mapMapper.coordinates(roadRoutes[index].points))
        render()
    }

    func startSearch(_ query: String, debounce: Bool) {
        let searchService = searchService
        let coordinate = locationSnapshot.coordinate
        let generation = operations.begin(.search)
        let lifecycle = operations.lifecycleGeneration
        searchTask = Task { [weak self] in
            do {
                let places = try await searchService.results(
                    for: query,
                    near: coordinate,
                    debounce: debounce
                )
                guard let self,
                      operations.isCurrent(.search, generation: generation, lifecycle: lifecycle) else { return }
                receiveSearchResults(places, query: query)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      let self,
                      operations.isCurrent(.search, generation: generation, lifecycle: lifecycle) else { return }
                receiveSearchFailure(query: query)
            }
        }
    }

    func receiveSearchResults(_ places: [NavigationPlace], query: String) {
        guard query == normalizedSearchQuery else { return }
        searchResults = places
        errorText = searchResults.isEmpty ? String(localized: .rideNavigationNoDestinationsFound) : nil
        render(isSearching: false)
    }

    func receiveSearchFailure(query: String) {
        guard query == normalizedSearchQuery else { return }
        errorText = String(localized: .rideNavigationSearchUnavailable)
        render(isSearching: false)
    }

    func recalculatePreviewRoutes(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace
    ) {
        let generation = operations.begin(.route)
        let lifecycle = operations.lifecycleGeneration
        isCalculatingRoadRoutes = true
        errorText = nil
        render()
        let roadRouteCalculator = roadRouteCalculator
        let preferences = roadRoutePreferences
        routeTask = Task { [weak self] in
            do {
                let routes = try await roadRouteCalculator.routes(
                    from: origin,
                    to: destination,
                    preferences: preferences
                )
                try Task.checkCancellation()
                guard let self,
                      operations.isCurrent(.route, generation: generation, lifecycle: lifecycle),
                      isStarted,
                      let firstRoute = routes.first else {
                    throw RoadRouteCalculationError.routeUnavailable
                }
                roadRoutes = routes
                selectedRoadRouteIndex = .zero
                roadRoute = firstRoute
                resetRoadStepGuidance()
                cameraMode = .overview(mapMapper.coordinates(firstRoute.points))
                errorText = nil
                isCalculatingRoadRoutes = false
                render()
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      operations.isCurrent(.route, generation: generation, lifecycle: lifecycle),
                      isStarted else { return }
                isCalculatingRoadRoutes = false
                errorText = String(localized: .rideNavigationPreferencesUpdateError)
                render()
            }
        }
    }

    func startApproachRoute(
        from origin: GeographicCoordinate,
        to start: GeographicCoordinate
    ) {
        let destination = NavigationPlace(
            name: String(localized: selectedDirection == .forward
                ? .rideNavigationTrailStart
                : .rideNavigationTrailFinish),
            detail: String(localized: .rideNavigationTrailApproachDetail),
            coordinate: start
        )
        roadRoutes = []
        selectedRoadRouteIndex = .zero
        let generation = operations.begin(.route)
        let lifecycle = operations.lifecycleGeneration
        let roadRouteCalculator = roadRouteCalculator
        let preferences = roadRoutePreferences
        routeTask = Task { [weak self] in
            do {
                let calculatedRoute = try await roadRouteCalculator.route(
                    from: origin,
                    to: destination,
                    preferences: preferences
                )
                try Task.checkCancellation()
                guard let self,
                      operations.isCurrent(.route, generation: generation, lifecycle: lifecycle),
                      isStarted else { return }
                roadRoute = calculatedRoute
                roadNavigationPurpose = .trailApproach
                resetRoadStepGuidance()
                selectedDestination = destination
                let date = now()
                startBreadcrumb(at: date)
                activityStartedAt = date
                activity = .navigating
                applyPreferredMapStyleForActiveNavigation()
                cameraMode = followCamera
                startClock()
                errorText = nil
                render()
                announce(String(localized: .rideNavigationAnnouncementTrailApproachStarted))
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      operations.isCurrent(.route, generation: generation, lifecycle: lifecycle),
                      isStarted else { return }
                errorText = String(localized: .rideNavigationApproachCalculationError)
                render()
            }
        }
    }
    func previewExternalDestination(_ destination: NavigationPlace) {
        guard let origin = locationSnapshot.coordinate else {
            pendingExternalDestination = destination
            errorText = String(localized: .rideNavigationCurrentLocationRequired)
            render()
            return
        }
        stopClock()
        screen = .map
        activity = .preview
        mapDisplayStyle = .map
        selectedRoute = nil
        trailMap.reset()
        trailProgress = nil
        trailExitPreview = nil
        roadNavigationPurpose = .destination
        selectedDestination = destination
        errorText = nil
        calculateRoadPreview(from: origin, to: destination, showsSearchLoading: false)
    }
}
