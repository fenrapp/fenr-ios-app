import CoreLocation
import MapboxMaps
import RideNavigation
import SwiftUI

@MainActor
public struct MapboxOfflineSelectorFactory {
    public init() {}

    public func makeFactory() -> OfflineMapSelectorFactory {
        OfflineMapSelectorFactory { scene, insets, onViewport in
            AnyView(MapboxOfflineSelector(scene: scene, insets: insets, onViewport: onViewport))
        }
    }
}

private struct MapboxOfflineSelector: UIViewRepresentable {
    let scene: OfflineMapSelectionScene
    let insets: OfflineMapSelectionInsets
    let onViewport: @MainActor (OfflineMapViewport) -> Void

    func makeCoordinator() -> MapboxOfflineSelectorCoordinator {
        MapboxOfflineSelectorCoordinator(onViewport: onViewport)
    }

    func makeUIView(context: Context) -> MapView {
        let map = MapView(frame: .zero, mapInitOptions: MapInitOptions(
            cameraOptions: CameraOptions(
                center: (scene.center ?? scene.outlines.first?.first)?.clCoordinate,
                zoom: scene.isCorridor ? 12 : 2, bearing: 0, pitch: 0
            ),
            styleURI: StyleURI(rawValue: "mapbox://styles/mapbox/outdoors-v12")
        ))
        map.gestures.options.rotateEnabled = false
        map.gestures.options.pitchEnabled = false
        map.ornaments.options.compass.visibility = .hidden
        map.ornaments.options.scaleBar.visibility = .hidden
        map.ornaments.options.logo.position = .topLeft
        map.ornaments.options.attributionButton.position = .topLeft
        context.coordinator.attach(map)
        return map
    }

    func updateUIView(_ map: MapView, context: Context) { context.coordinator.update(scene, insets: insets, on: map) }

    static func dismantleUIView(_ map: MapView, coordinator: MapboxOfflineSelectorCoordinator) { coordinator.stop() }
}

@MainActor
private final class MapboxOfflineSelectorCoordinator {
    private let onViewport: @MainActor (OfflineMapViewport) -> Void
    private var loadObservation: AnyCancelable?
    private var observation: AnyCancelable?
    private var insets = OfflineMapSelectionInsets()
    private var lastViewport: OfflineMapViewport?
    private var outlines: PolylineAnnotationManager?
    private var scene: OfflineMapSelectionScene?

    init(onViewport: @escaping @MainActor (OfflineMapViewport) -> Void) {
        self.onViewport = onViewport
    }

    func attach(_ map: MapView) {
        outlines = map.annotations.makePolylineAnnotationManager()
        loadObservation = map.mapboxMap.onMapLoaded.observeNext { [weak self, weak map] _ in
            guard let self, let map, let value = self.scene else { return }
            self.scene = nil
            self.update(value, insets: self.insets, on: map)
            self.lastViewport = nil
            self.publishViewport(map)
        }
        observation = map.mapboxMap.onMapIdle.observe { [weak self, weak map] _ in
            if let map { self?.publishViewport(map) }
        }
    }

    private func publishViewport(_ map: MapView) {
        guard map.bounds.width > 0, map.bounds.height > 0 else { return }
        let rect = map.bounds.inset(by: UIEdgeInsets(
            top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing
        ))
        guard rect.width > 0, rect.height > 0 else { return }
        let northwest = map.mapboxMap.coordinate(for: CGPoint(x: rect.minX, y: rect.minY))
        let southeast = map.mapboxMap.coordinate(for: CGPoint(x: rect.maxX, y: rect.maxY))
        let viewport = OfflineMapViewport(
            west: northwest.longitude, south: southeast.latitude,
            east: southeast.longitude, north: northwest.latitude
        )
        guard viewport != lastViewport else { return }
        lastViewport = viewport
        onViewport(viewport)
    }

    func stop() {
        loadObservation?.cancel()
        observation?.cancel()
        observation = nil
        outlines = nil
    }

    func update(_ value: OfflineMapSelectionScene, insets: OfflineMapSelectionInsets, on map: MapView) {
        let viewportChanged = self.insets != insets
        if viewportChanged {
            self.insets = insets
            lastViewport = nil
            map.mapboxMap.setCamera(to: CameraOptions(padding: UIEdgeInsets(
                top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing
            )))
        }
        let hasSidePanel = !value.isCorridor && map.bounds.width > map.bounds.height
        map.ornaments.options.logo.position = hasSidePanel ? .topRight : .topLeft
        map.ornaments.options.attributionButton.position = hasSidePanel ? .topRight : .topLeft
        let logoSize = map.ornaments.logoView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let attributionSize = map.ornaments.attributionButton.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        )
        // The SDK draws its info glyph at the bottom of the larger tap target.
        let rowHeight = max(logoSize.height, attributionSize.height)
        map.ornaments.options.attributionButton.margins = CGPoint(
            x: hasSidePanel ? Constants.ornamentMargin : logoSize.width + Constants.ornamentSpacing,
            y: Constants.ornamentMargin + rowHeight - attributionSize.height
        )
        map.ornaments.options.logo.margins = CGPoint(
            x: hasSidePanel ? attributionSize.width + Constants.ornamentSpacing : Constants.ornamentMargin,
            y: Constants.ornamentMargin + rowHeight - logoSize.height
        )
        if scene?.outlines != value.outlines || scene?.existing != value.existing || viewportChanged {
            let visibleOutlines = value.existing + (value.isCorridor ? value.outlines : [])
            outlines?.annotations = visibleOutlines.enumerated().map { index, points in
                var line = PolylineAnnotation(id: "selection-\(index)", lineCoordinates: points.map(\.clCoordinate))
                line.lineColor = StyleColor(index < value.existing.count ? .systemGreen : .systemBlue)
                line.lineWidth = Constants.lineWidth
                return line
            }
            if value.isCorridor, !value.outlines.isEmpty,
               let camera = try? map.mapboxMap.camera(
                for: value.outlines.flatMap { $0 }.map(\.clCoordinate),
                camera: CameraOptions(bearing: 0, pitch: 0), coordinatesPadding: Constants.padding,
                maxZoom: Constants.maximumZoom, offset: nil
               ) {
                map.mapboxMap.setCamera(to: camera)
            }
        }
        if !value.isCorridor, scene?.center == nil, let center = value.center {
            map.mapboxMap.setCamera(to: CameraOptions(center: center.clCoordinate, zoom: Constants.initialZoom))
        }
        if let scene, scene.cameraCommand != value.cameraCommand, let center = value.center {
            map.mapboxMap.setCamera(to: CameraOptions(center: center.clCoordinate))
        }
        scene = value
    }

    private enum Constants {
        static let ornamentMargin = 8.0
        static let ornamentSpacing = 12.0
        static let lineWidth = 2.0
        static let initialZoom = 12.0
        static let maximumZoom = 16.0
        static let padding = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
    }
}
