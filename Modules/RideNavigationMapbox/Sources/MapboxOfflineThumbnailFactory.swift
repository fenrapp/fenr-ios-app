import MapboxMaps
import RideNavigation
import SwiftUI

@MainActor
public enum MapboxOfflineThumbnailFactory {
    public static func make(directory: URL) -> OfflineMapThumbnailFactory {
        let memory = NSCache<NSString, UIImage>()
        memory.countLimit = Constants.memoryLimit
        let cache = MapboxOfflineThumbnailCache(directory: directory, files: .default, memory: memory)
        return OfflineMapThumbnailFactory { area in
            AnyView(MapboxOfflineThumbnail(
                area: area, cache: cache, makeSnapshotter: { Snapshotter(options: $0) }
            ))
        }
    }
    private enum Constants {
        static let memoryLimit = 80
    }
}

private struct MapboxOfflineThumbnail: UIViewRepresentable {
    let area: OfflineAreaRow
    let cache: MapboxOfflineThumbnailCache
    let makeSnapshotter: (MapSnapshotOptions) -> Snapshotter

    func makeCoordinator() -> MapboxOfflineThumbnailCoordinator {
        MapboxOfflineThumbnailCoordinator(cache: cache, makeSnapshotter: makeSnapshotter)
    }

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .secondarySystemGroupedBackground
        view.tintColor = .secondaryLabel
        return view
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        context.coordinator.render(area, on: view)
    }

    static func dismantleUIView(_ view: UIImageView, coordinator: MapboxOfflineThumbnailCoordinator) {
        coordinator.stop()
    }
}
