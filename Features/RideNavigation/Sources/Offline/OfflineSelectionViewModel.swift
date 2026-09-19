import EnvironmentDomain
import Foundation
import Observation
import OfflineMapsDomain

@MainActor
@Observable
public final class OfflineSelectionViewModel {
    public var name: String
    public private(set) var satellite = false
    public private(set) var marginKilometers = 2
    public private(set) var estimateText = String(localized: .offlineSizeUnavailable)
    public private(set) var transferText: String?
    public private(set) var freeText = ""
    public private(set) var isEstimating = false
    public private(set) var canDownload = false
    public private(set) var didEnqueue = false
    public private(set) var errorText: String?
    public private(set) var coverageText: String?
    public private(set) var wifiOnly = true
    public private(set) var scene: OfflineMapSelectionScene
    public let isRoute: Bool
    private let observePosition: ObserveDeviceSpeedUseCase?
    private var currentCenter: NavigationMapCoordinate?
    @ObservationIgnored private var positionTask: Task<Void, Never>?
    private let seed: OfflineMapSelectionSeed
    private let useCases: OfflineMapsUseCases
    private let mapper: OfflineMapsPresentationMapper
    private var geometry = OfflineGeometry(rectangles: [])
    private var estimate: OfflineMapEstimate?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var policyTask: Task<Void, Never>?
    private var generation = 0

    public init(
        seed: OfflineMapSelectionSeed, useCases: OfflineMapsUseCases, mapper: OfflineMapsPresentationMapper,
        observePosition: ObserveDeviceSpeedUseCase? = nil
    ) {
        self.observePosition = observePosition
        self.seed = seed
        self.useCases = useCases
        self.mapper = mapper
        name = seed.name
        isRoute = !seed.segments.isEmpty
        scene = OfflineMapSelectionScene(
            outlines: [], existing: [], center: seed.center, isCorridor: !seed.segments.isEmpty
        )
    }

    deinit { task?.cancel(); policyTask?.cancel(); positionTask?.cancel() }

    public func start() {
        positionTask?.cancel()
        if let observePosition {
            positionTask = Task { [weak self] in
                let stream = await observePosition.execute()
                for await sample in stream {
                    guard !Task.isCancelled, let self else { return }
                    if let coordinate = sample.coordinate {
                        currentCenter = NavigationMapCoordinate(
                            latitudeDegrees: coordinate.latitudeDegrees, longitudeDegrees: coordinate.longitudeDegrees
                        )
                        updateScene()
                    }
                }
            }
        }
        wifiOnly = useCases.snapshot.wifiOnly
        freeText = mapper.bytes(useCases.snapshot.freeBytes)
        if isRoute, geometry.rectangles.isEmpty {
            setMargin(marginKilometers)
        } else {
            updateScene()
            if !geometry.rectangles.isEmpty { refreshEstimate() }
        }
    }

    public func stop() {
        generation += 1
        task?.cancel()
        policyTask?.cancel()
        positionTask?.cancel()
        isEstimating = false
        canDownload = false
    }

    public func setViewport(_ viewport: OfflineMapViewport) {
        guard !isRoute else { return }
        let value = useCases.geometry.rectangle(
            west: viewport.west, south: viewport.south, east: viewport.east, north: viewport.north
        )
        guard value != geometry else { return }
        geometry = value
        refreshEstimate()
    }

    public func setMargin(_ value: Int) {
        guard [2, 5, 10].contains(value) else { return }
        marginKilometers = value
        geometry = useCases.geometry.corridor(segments: seed.segments.map { segment in
            segment.map { OfflineCoordinate(latitude: $0.latitudeDegrees, longitude: $0.longitudeDegrees) }
        }, marginMeters: Double(value) * 1_000)
        updateScene()
        refreshEstimate()
    }

    public func setSatellite(_ value: Bool) { satellite = value; refreshEstimate() }

    public func setWiFiOnly(_ value: Bool) {
        policyTask?.cancel()
        policyTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await useCases.perform(.wifiOnly(value))
                try Task.checkCancellation()
                wifiOnly = value
                refreshEstimate()
            } catch { if !Task.isCancelled { errorText = mapper.error(.catalog) } }
        }
    }

    public func locate() {
        scene = OfflineMapSelectionScene(
            outlines: scene.outlines, existing: scene.existing,
            center: currentCenter ?? seed.center, isCorridor: isRoute,
            cameraCommand: scene.cameraCommand + 1
        )
    }

    public func refreshEstimate() {
        generation += 1
        let current = generation
        task?.cancel()
        estimate = nil
        transferText = nil
        canDownload = false
        isEstimating = true
        errorText = nil
        coverageText = nil
        let available = useCases.snapshot.regions.filter { region in
            region.maximumZoom >= 16 && region.layers.contains { $0.layer == .topographic && $0.available }
        }.map(\.geometry)
        if useCases.geometry.availability(of: geometry, within: available) == .complete {
            coverageText = String(localized: .offlineAlreadyCovered)
        }
        let selectedLayers: [OfflineLayer] = satellite ? OfflineLayer.allCases : [.topographic]
        let alreadyAvailable = selectedLayers.allSatisfy { layer in
            let regions = useCases.snapshot.regions.filter {
                $0.maximumZoom >= 16 && $0.layers.contains { $0.layer == layer && $0.available }
            }.map(\.geometry)
            return useCases.geometry.availability(of: geometry, within: regions) == .complete
        }
        if isRoute, alreadyAvailable {
            isEstimating = false
            estimateText = String(localized: .offlineAlreadyCovered)
            return
        }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(400))
                let result = try await useCases.estimate(request)
                try Task.checkCancellation()
                guard generation == current else { return }
                estimate = result
                let size = mapper.bytes(Int64(clamping: result.storageBytes))
                estimateText = String(localized: .offlineEstimatedSize(size))
                let transfer = mapper.bytes(Int64(clamping: result.transferBytes))
                transferText = String(localized: .offlineEstimatedTransfer(transfer))
                canDownload = result.storageBytes < UInt64(max(0, useCases.snapshot.freeBytes - 1_000_000_000))
                if !canDownload { errorText = mapper.error(.insufficientStorage) }
            } catch {
                guard !Task.isCancelled, generation == current else { return }
                estimateText = String(localized: .offlineSizeUnavailable)
                errorText = mapper.error((error as? OfflineMapsFailure) ?? .provider)
            }
            isEstimating = false
        }
    }

    public func download() {
        guard let estimate, canDownload else { return }
        do {
            try useCases.enqueue(request, estimate: estimate)
            didEnqueue = true
        } catch { errorText = mapper.error((error as? OfflineMapsFailure) ?? .provider) }
    }

    private var request: OfflineMapRequest {
        OfflineMapRequest(name: name, geometry: geometry, routeID: seed.routeID, satellite: satellite)
    }

    private func updateScene() {
        scene = OfflineMapSelectionScene(
            outlines: mapper.outlines(geometry),
            existing: useCases.snapshot.regions.filter { $0.layers.contains(where: \.available) }
                .flatMap { mapper.outlines($0.geometry) },
            center: currentCenter ?? seed.center, isCorridor: isRoute,
            cameraCommand: scene.cameraCommand
        )
    }
}
