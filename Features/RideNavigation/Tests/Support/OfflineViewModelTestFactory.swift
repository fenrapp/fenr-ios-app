import Foundation
import OfflineMapsDomain
@testable import RideNavigation

@MainActor
enum OfflineViewModelTestFactory {
    static func useCases(_ repository: OfflineMapsRepositorySpy) -> OfflineMapsUseCases {
        OfflineMapsUseCases(repository: repository, geometry: OfflineGeometryService())
    }

    static func library(_ repository: OfflineMapsRepositorySpy) -> OfflineLibraryViewModel {
        OfflineLibraryViewModel(
            useCases: useCases(repository), mapper: OfflineMapsPresentationMapper(),
            routeLoader: { _ in OfflineMapSelectionSeed(name: "Synthetic") }
        )
    }

    static func detail(_ repository: OfflineMapsRepositorySpy, id: UUID) -> OfflineDetailViewModel {
        OfflineDetailViewModel(id: id, useCases: useCases(repository), mapper: OfflineMapsPresentationMapper())
    }

    static func selection(_ repository: OfflineMapsRepositorySpy) -> OfflineSelectionViewModel {
        OfflineSelectionViewModel(
            seed: OfflineMapSelectionSeed(name: "Synthetic"),
            useCases: useCases(repository), mapper: OfflineMapsPresentationMapper()
        )
    }
}
