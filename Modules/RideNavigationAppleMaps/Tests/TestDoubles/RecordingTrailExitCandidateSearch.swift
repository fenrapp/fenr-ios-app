import EnvironmentDomain
import RideNavigationDomain

actor RecordingTrailExitCandidateSearch: TrailExitCandidateSearching {
    private let results: [NavigationPlace]
    private var radii: [Double] = []

    init(results: [NavigationPlace]) {
        self.results = results
    }

    func candidates(near _: GeographicCoordinate, radiusMeters: Double) async throws -> [NavigationPlace] {
        radii.append(radiusMeters)
        return results
    }

    func requestedRadii() -> [Double] {
        radii
    }
}
