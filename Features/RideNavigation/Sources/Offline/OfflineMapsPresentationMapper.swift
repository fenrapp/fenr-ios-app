import Foundation
import OfflineMapsDomain

public struct OfflineMapsPresentationMapper {
    public init() {}

    public func library(_ snapshot: OfflineMapsSnapshot, now: Date) -> OfflineLibraryState {
        OfflineLibraryState(
            areas: snapshot.regions.map { area($0, now: now, networkAllowed: snapshot.isDownloadNetworkAllowed) },
            used: bytes(snapshot.usedBytes), free: bytes(snapshot.freeBytes), wifiOnly: snapshot.wifiOnly,
            isLoading: !snapshot.isReconciled, error: snapshot.failure.map(error)
        )
    }

    public func area(_ region: OfflineRegion, now: Date, networkAllowed: Bool = true) -> OfflineAreaRow {
        let oldestUpdate = region.layers.compactMap(\.updatedAt).min()
        let shouldSuggestUpdate = oldestUpdate.map {
            now.timeIntervalSince($0) > Constants.updateReminderInterval
        } ?? false
        let ready = region.layers.filter(\.available).map { layerName($0.layer) }.joined(separator: ", ")
        let waiting = !networkAllowed && [.queued, .interrupted, .waitingForWiFi].contains(region.status)
        return OfflineAreaRow(
            id: region.id, name: region.name, thumbnailRevision: region.layers.compactMap(\.updatedAt).max(),
            explanation: explanation(region, waiting: waiting),
            progressText: region.progress.formatted(.percent.precision(.fractionLength(0))),
            canUpdate: region.status == .ready,
            layerRows: region.layers.map { layer in
                OfflineAreaRow.Layer(
                    id: layer.layer.rawValue, title: layerName(layer.layer),
                    detail: String(localized: layer.available ? .offlineLayerAvailable : .offlineLayerPending),
                    symbol: layer.layer == .topographic ? "mountain.2.fill" : "globe.europe.africa.fill"
                )
            },
            status: waiting ? String(localized: .offlineWaitingForNetwork) : status(region.status),
            symbol: waiting ? "wifi" : symbol(region.status),
            layers: ready.isEmpty ? String(localized: .offlineNoLayers) : ready,
            size: bytes(Int64(clamping: region.completedBytes)),
            updated: oldestUpdate?.formatted(date: .abbreviated, time: .omitted)
                ?? String(localized: .offlineNeverDownloaded),
            reminder: shouldSuggestUpdate ? String(localized: .offlineUpdateReminder) : nil,
            progress: region.status == .downloading ? region.progress : nil,
            canPause: [.queued, .downloading, .waitingForWiFi, .interrupted].contains(region.status),
            canResume: [.paused, .failed].contains(region.status), outlines: outlines(region.geometry)
        )
    }

    public func outlines(_ geometry: OfflineGeometry) -> [[NavigationMapCoordinate]] {
        geometry.rectangles.map { bounds in
            [(bounds.south, bounds.west), (bounds.south, bounds.east), (bounds.north, bounds.east),
             (bounds.north, bounds.west), (bounds.south, bounds.west)].compactMap {
                NavigationMapCoordinate(latitudeDegrees: $0.0, longitudeDegrees: $0.1)
            }
        }
    }

    public func bytes(_ value: Int64) -> String {
        value.formatted(.byteCount(style: .file))
    }

    public func error(_ failure: OfflineMapsFailure) -> String {
        switch failure {
        case .invalidSelection: String(localized: .offlineInvalidSelection)
        case .insufficientStorage: String(localized: .offlineStorageError)
        case .providerLimit: String(localized: .offlineProviderLimit)
        case .network: String(localized: .offlineNetworkError)
        case .configuration: String(localized: .offlineConfigurationError)
        case .catalog: String(localized: .offlineCatalogError)
        case .provider: String(localized: .offlineDownloadError)
        }
    }

    private func explanation(_ region: OfflineRegion, waiting: Bool) -> String {
        if let failure = region.failure { return error(failure) }
        if waiting { return String(localized: .offlineWaitingExplanation) }
        if region.isUpdating { return String(localized: .offlineUpdatingExplanation) }
        switch region.status {
        case .ready: return String(localized: .offlineReadyExplanation)
        case .paused: return String(localized: .offlinePausedExplanation)
        case .downloading: return String(localized: .offlineDownloadingExplanation)
        case .queued: return String(localized: .offlineQueuedExplanation)
        case .waitingForWiFi, .interrupted: return String(localized: .offlineWaitingExplanation)
        case .failed: return String(localized: .offlineDownloadError)
        }
    }

    private func layerName(_ layer: OfflineLayer) -> String {
        layer == .topographic ? String(localized: .offlineTopographic) : String(localized: .offlineSatellite)
    }

    private func status(_ value: OfflineDownloadStatus) -> String {
        switch value {
        case .queued: String(localized: .offlineQueued)
        case .downloading: String(localized: .offlineDownloading)
        case .paused: String(localized: .offlinePaused)
        case .waitingForWiFi: String(localized: .offlineWaitingForNetwork)
        case .interrupted: String(localized: .offlineInterrupted)
        case .ready: String(localized: .offlineReady)
        case .failed: String(localized: .offlineDownloadError)
        }
    }

    private func symbol(_ status: OfflineDownloadStatus) -> String {
        switch status {
        case .ready: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle"
        case .paused, .interrupted: "pause.circle"
        case .waitingForWiFi: "wifi"
        case .queued, .downloading: "arrow.down.circle"
        }
    }

    private enum Constants {
        static let updateReminderInterval: TimeInterval = 30 * 24 * 60 * 60
    }

}
