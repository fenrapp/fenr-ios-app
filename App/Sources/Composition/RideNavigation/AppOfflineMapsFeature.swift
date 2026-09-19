import EnvironmentDomain
import Foundation
import OfflineMapsData
import OfflineMapsDomain
import RideNavigation
import RideNavigationMapbox
import SwiftUI

@MainActor
struct AppOfflineMapsFeature {
    let orientation: InterfaceOrientationController
    let service: OfflineMapsController
    let useCases: OfflineMapsUseCases

    static func make() -> AppOfflineMapsFeature {
        let directory = URL.applicationSupportDirectory.appendingPathComponent("OfflineMaps", isDirectory: true)
        let service = MapboxOfflineAssembly.make(directory: directory)
        return AppOfflineMapsFeature(
            orientation: .shared, service: service,
            useCases: OfflineMapsUseCases(repository: service, geometry: OfflineGeometryService())
        )
    }

    func makeFactory(
        observePosition: ObserveDeviceSpeedUseCase,
        routeLoader: @escaping @MainActor (UUID) async throws -> OfflineMapSelectionSeed
    ) -> OfflineMapsFeatureFactory {
        let mapper = OfflineMapsPresentationMapper()
        let selector = MapboxOfflineSelectorFactory().makeFactory()
        let thumbnails = MapboxOfflineThumbnailFactory.make(
            directory: URL.cachesDirectory.appendingPathComponent("OfflineMapThumbnails", isDirectory: true)
        )
        return OfflineMapsFeatureFactory { routeID, seed in
            AnyView(OfflineMapsLibraryView(
                model: OfflineLibraryViewModel(useCases: useCases, mapper: mapper, routeLoader: routeLoader),
                routeID: routeID, seed: seed,
                selectionBuilder: { seed in
                    AnyView(OfflineMapSelectionView(
                        model: OfflineSelectionViewModel(
                            seed: seed, useCases: useCases, mapper: mapper, observePosition: observePosition
                        ),
                        selector: selector
                    ).modifier(AppOfflineMapsOrientation(orientation: orientation)))
                },
                thumbnailFactory: thumbnails,
                detailBuilder: { id in
                    AnyView(OfflineMapDetailView(
                        model: OfflineDetailViewModel(id: id, useCases: useCases, mapper: mapper), selector: selector
                    ).modifier(AppOfflineMapsOrientation(orientation: orientation)))
                }
            ).modifier(AppOfflineMapsOrientation(orientation: orientation)))
        }
    }
}

private struct AppOfflineMapsOrientation: ViewModifier {
    let orientation: InterfaceOrientationController
    @State private var presentationID = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { orientation.beginAdaptivePresentation(presentationID) }
            .onDisappear { orientation.endAdaptivePresentation(presentationID) }
    }
}
