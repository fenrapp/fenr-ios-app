import EnvironmentDomain
import Foundation

@MainActor
extension RideNavigationPlanningController {
    func updateSearchQuery(_ value: String, near coordinate: GeographicCoordinate?) {
        cancelPreviewForSearch()
        snapshot.searchQuery = value
        cancel(.search)
        snapshot.errorMessage = nil
        let query = normalizedSearchQuery
        guard query.count >= Constants.minimumSearchCharacters else {
            snapshot.searchResults = []
            publish()
            return
        }
        startSearch(query, near: coordinate, debounce: true)
    }

    func search(near coordinate: GeographicCoordinate?) {
        guard normalizedSearchQuery.count >= Constants.minimumSearchCharacters else { return }
        cancelPreviewForSearch()
        startSearch(normalizedSearchQuery, near: coordinate, debounce: false)
    }

    var normalizedSearchQuery: String {
        snapshot.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cancelPreviewForSearch() {
        switch roadRequest {
        case .preview, .refreshPreview:
            cancel(.road)
            previewPresentationPending = false
        default: break
        }
    }

    private func startSearch(_ query: String, near coordinate: GeographicCoordinate?, debounce: Bool) {
        let token = begin(.search)
        snapshot.isSearchLoading = true
        publish()
        searchTask = Task { [weak self, searchService] in
            do {
                let places = try await searchService.results(for: query, near: coordinate, debounce: debounce)
                guard !Task.isCancelled, let self, isCurrent(token), query == normalizedSearchQuery else { return }
                searchTask = nil
                snapshot.searchResults = places
                snapshot.isSearchLoading = false
                snapshot.errorMessage = places.isEmpty ? String(localized: .rideNavigationNoDestinationsFound) : nil
                publish(token: token)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self, isCurrent(token), query == normalizedSearchQuery else { return }
                searchTask = nil
                snapshot.isSearchLoading = false
                snapshot.errorMessage = String(localized: .rideNavigationSearchUnavailable)
                publish(token: token)
            }
        }
    }
}
