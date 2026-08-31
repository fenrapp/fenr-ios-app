import EnvironmentDomain
import RideNavigationDomain

actor RecordingTrailExitCandidateSearch: TrailExitCandidateSearching {
    private let defaultResults: [NavigationPlace]
    private let resultsByRadius: [Double: [NavigationPlace]]
    private var radii: [Double] = []

    init(results: [NavigationPlace]) {
        defaultResults = results
        resultsByRadius = [:]
    }

    init(resultsByRadius: [Double: [NavigationPlace]]) {
        defaultResults = []
        self.resultsByRadius = resultsByRadius
    }

    func candidates(near _: GeographicCoordinate, radiusMeters: Double) async throws -> [NavigationPlace] {
        radii.append(radiusMeters)
        return resultsByRadius[radiusMeters] ?? defaultResults
    }

    func requestedRadii() -> [Double] {
        radii
    }
}
