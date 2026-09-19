import Foundation
import Observation
import OfflineMapsDomain

@MainActor
@Observable
public final class OfflineLibraryViewModel {
    public private(set) var state: OfflineLibraryState
    public var selection: OfflineMapSelectionSeed?
    public private(set) var busyAreaIDs: Set<UUID> = []
    private var generation = 0
    public private(set) var errorText: String?
    private let useCases: OfflineMapsUseCases
    private let mapper: OfflineMapsPresentationMapper
    private let routeLoader: @MainActor (UUID) async throws -> OfflineMapSelectionSeed
    private var observer: UUID?
    private var didOpenInitialSelection = false
    @ObservationIgnored private var operation: Task<Void, Never>?

    public init(
        useCases: OfflineMapsUseCases, mapper: OfflineMapsPresentationMapper,
        routeLoader: @escaping @MainActor (UUID) async throws -> OfflineMapSelectionSeed
    ) {
        self.useCases = useCases
        self.mapper = mapper
        self.routeLoader = routeLoader
        state = mapper.library(useCases.snapshot, now: Date())
    }

    deinit { operation?.cancel() }

    public func start(routeID: UUID?, seed: OfflineMapSelectionSeed?) {
        guard observer == nil else { return }
        observer = useCases.observe { [weak self] value in
            guard let self else { return }
            self.state = self.mapper.library(value, now: Date())
        }
        guard !didOpenInitialSelection else { return }
        didOpenInitialSelection = true
        if let seed { selection = seed }
        if let routeID {
            operation?.cancel()
            operation = Task { [weak self] in
                guard let self else { return }
                do {
                    let seed = try await routeLoader(routeID)
                    try Task.checkCancellation()
                    selection = seed
                } catch {
                    if !Task.isCancelled { errorText = String(localized: .rideNavigationSavedRouteReadError) }
                }
            }
        }
    }

    public func stop() {
        generation += 1
        busyAreaIDs.removeAll()
        operation?.cancel()
        operation = nil
        if let observer { useCases.removeObserver(observer) }
        observer = nil
    }

    public func selectArea() {
        selection = OfflineMapSelectionSeed(name: String(localized: .offlineAreaName(state.areas.count + 1)))
    }

    public func pause(_ id: UUID) { perform(.pause(id)) }
    public func resume(_ id: UUID) { perform(.resume(id)) }

    public func update(_ id: UUID) {
        guard state.areas.first(where: { $0.id == id })?.canUpdate == true else { return }
        perform(.update(id), areaID: id)
    }

    public func delete(_ id: UUID) {
        guard state.areas.contains(where: { $0.id == id }) else { return }
        perform(.delete(id), areaID: id)
    }

    private func perform(_ command: OfflineMapCommand, areaID: UUID? = nil) {
        if let areaID, !busyAreaIDs.insert(areaID).inserted { return }
        let current = generation
        let previous = operation
        operation = Task { [weak self] in
            await withTaskCancellationHandler { await previous?.value } onCancel: { previous?.cancel() }
            guard let self else { return }
            defer { if generation == current, let areaID { busyAreaIDs.remove(areaID) } }
            guard !Task.isCancelled, generation == current else { return }
            errorText = nil
            do { try await useCases.perform(command) } catch {
                if !Task.isCancelled, generation == current {
                    errorText = mapper.error((error as? OfflineMapsFailure) ?? .provider)
                }
            }
        }
    }

    public func setWiFiOnly(_ value: Bool) { perform(.wifiOnly(value)) }
}
