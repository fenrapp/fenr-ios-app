import Foundation
import Observation
import OfflineMapsDomain

@MainActor
@Observable
public final class OfflineDetailViewModel {
    public private(set) var area: OfflineAreaRow?
    public var name = ""
    public private(set) var errorText: String?
    public private(set) var isBusy = false
    public private(set) var didDelete = false
    private let id: UUID
    private let useCases: OfflineMapsUseCases
    private let mapper: OfflineMapsPresentationMapper
    private var observer: UUID?
    private var generation = 0
    @ObservationIgnored private var task: Task<Void, Never>?

    public init(id: UUID, useCases: OfflineMapsUseCases, mapper: OfflineMapsPresentationMapper) {
        self.id = id
        self.useCases = useCases
        self.mapper = mapper
    }

    deinit { task?.cancel() }

    public func start() {
        guard observer == nil else { return }
        observer = useCases.observe { [weak self] value in
            guard let self, let region = value.regions.first(where: { $0.id == self.id }) else { return }
            self.area = self.mapper.area(region, now: Date(), networkAllowed: value.isDownloadNetworkAllowed)
            if self.name.isEmpty { self.name = region.name }
        }
    }

    public func stop() {
        generation += 1
        task?.cancel()
        isBusy = false
        if let observer { useCases.removeObserver(observer) }
        observer = nil
    }

    public func pause() { perform(.pause(id)) }
    public func resume() { perform(.resume(id)) }
    public func update() { perform(.update(id)) }
    public func rename() { perform(.rename(id, name)) }
    public func delete() { perform(.delete(id), deleting: true) }

    private func perform(_ command: OfflineMapCommand, deleting: Bool = false) {
        guard !isBusy else { return }
        isBusy = true
        errorText = nil
        task?.cancel()
        let current = generation
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await useCases.perform(command)
                try Task.checkCancellation()
                guard generation == current else { return }
                didDelete = deleting
            } catch {
                if !Task.isCancelled, generation == current {
                    errorText = mapper.error((error as? OfflineMapsFailure) ?? .provider)
                }
            }
            if generation == current { isBusy = false }
        }
    }
}
