import EnvironmentDomain
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

    static func selection(
        _ repository: OfflineMapsRepositorySpy,
        seed: OfflineMapSelectionSeed = OfflineMapSelectionSeed(name: "Synthetic"),
        position: TestDeviceSpeedRepository? = nil
    ) -> OfflineSelectionViewModel {
        OfflineSelectionViewModel(
            seed: seed, useCases: useCases(repository), mapper: OfflineMapsPresentationMapper(),
            observePosition: position.map { ObserveDeviceSpeedUseCase(repository: $0) }
        )
    }
}
