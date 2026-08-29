import EnvironmentDomain
import RideNavigationDomain

actor ControllablePlaceSearch: PlaceSearching {
    enum Failure: Error {
        case unavailable
    }

    private var continuations: [String: CheckedContinuation<[NavigationPlace], any Error>] = [:]
    private var completedQueries: Set<String> = []

    func search(_ query: String, near _: GeographicCoordinate?) async throws -> [NavigationPlace] {
        do {
            let places = try await withCheckedThrowingContinuation { continuation in
                continuations[query] = continuation
            }
            completedQueries.insert(query)
            return places
        } catch {
            completedQueries.insert(query)
            throw error
        }
    }

    func hasRequest(for query: String) -> Bool {
        continuations[query] != nil
    }

    func succeed(query: String, places: [NavigationPlace]) {
        continuations.removeValue(forKey: query)?.resume(returning: places)
    }

    func fail(query: String) {
        continuations.removeValue(forKey: query)?.resume(throwing: Failure.unavailable)
    }

    func hasCompletedRequest(for query: String) -> Bool {
        completedQueries.contains(query)
    }
}
