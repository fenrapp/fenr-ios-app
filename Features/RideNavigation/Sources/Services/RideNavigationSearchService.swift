import EnvironmentDomain
import Foundation
import RideNavigationDomain

public struct RideNavigationSearchService: Sendable {
    private let placeSearch: any PlaceSearching
    private let sleep: @Sendable (Duration) async throws -> Void
    private let debounceDuration: Duration
    private let maximumResultCount: Int

    public init(
        placeSearch: any PlaceSearching,
        sleep: @escaping @Sendable (Duration) async throws -> Void,
        debounceDuration: Duration = .milliseconds(300),
        maximumResultCount: Int = 8
    ) {
        self.placeSearch = placeSearch
        self.sleep = sleep
        self.debounceDuration = debounceDuration
        self.maximumResultCount = maximumResultCount
    }

    func results(
        for query: String,
        near coordinate: GeographicCoordinate?,
        debounce: Bool
    ) async throws -> [NavigationPlace] {
        if debounce {
            try await sleep(debounceDuration)
        }
        try Task.checkCancellation()
        let places = try await placeSearch.search(query, near: coordinate)
        try Task.checkCancellation()
        return Array(places.prefix(maximumResultCount))
    }
}
