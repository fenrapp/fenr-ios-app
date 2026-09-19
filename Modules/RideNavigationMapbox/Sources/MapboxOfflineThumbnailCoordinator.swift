import MapboxMaps
import RideNavigation
import UIKit

@MainActor
final class MapboxOfflineThumbnailCoordinator {
    private let cache: MapboxOfflineThumbnailCache
    private let makeSnapshotter: (MapSnapshotOptions) -> Snapshotter
    private var snapshotter: Snapshotter?
    private var timeout: Task<Void, Never>?
    private var currentKey: String?
    private var generation = 0

    init(cache: MapboxOfflineThumbnailCache, makeSnapshotter: @escaping (MapSnapshotOptions) -> Snapshotter) {
        self.cache = cache
        self.makeSnapshotter = makeSnapshotter
    }

    deinit { timeout?.cancel() }

    func render(_ area: OfflineAreaRow, on view: UIImageView) {
        let revision = area.thumbnailRevision?.timeIntervalSince1970 ?? 0
        let key = "\(area.id.uuidString)-v1-\(revision)"
        guard currentKey != key else { return }
        stop()
        currentKey = key
        let cached = cache.image(key: key)
        view.image = cached ?? UIImage(systemName: "map")
        if cached != nil { return }
        let coordinates = area.outlines.flatMap { $0 }.map(\.clCoordinate)
        guard !coordinates.isEmpty else { return }
        let current = generation
        let snapshotter = makeSnapshotter(MapSnapshotOptions(size: Constants.size, pixelRatio: Constants.pixelRatio))
        self.snapshotter = snapshotter
        snapshotter.load(mapStyle: .outdoors)
        snapshotter.setCamera(to: snapshotter.camera(
            for: coordinates, padding: Constants.padding, bearing: 0, pitch: 0
        ))
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(Constants.timeoutSeconds)) } catch { return }
            guard !Task.isCancelled, let self, generation == current else { return }
            stop()
        }
        snapshotter.start(overlayHandler: { overlay in
            Self.draw(area.outlines, on: overlay)
        }, completion: { [weak self, weak view] result in
            guard let self, generation == current, currentKey == key else { return }
            timeout?.cancel()
            timeout = nil
            if case .success(let image) = result {
                cache.store(image, key: key, areaID: area.id)
                view?.image = image
            }
            self.snapshotter = nil
        })

    }

    func stop() {
        generation += 1
        timeout?.cancel()
        timeout = nil
        snapshotter?.cancel()
        snapshotter = nil
        currentKey = nil
    }

    private static func draw(_ outlines: [[NavigationMapCoordinate]], on overlay: SnapshotOverlay) {
        let context = overlay.context
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setFillColor(UIColor.systemBlue.withAlphaComponent(Constants.fillOpacity).cgColor)
        context.setLineWidth(Constants.lineWidth)
        for outline in outlines {
            guard let first = outline.first else { continue }
            context.beginPath()
            context.move(to: overlay.pointForCoordinate(first.clCoordinate))
            for point in outline.dropFirst() { context.addLine(to: overlay.pointForCoordinate(point.clCoordinate)) }
            context.closePath()
            context.drawPath(using: .fillStroke)
        }
    }

    private enum Constants {
        static let size = CGSize(width: 200, height: 160)
        static let pixelRatio = 2.0
        static let padding = UIEdgeInsets(top: 16, left: 16, bottom: 40, right: 16)
        static let fillOpacity = 0.08
        static let lineWidth = 2.0
        static let timeoutSeconds = 15.0
    }
}
