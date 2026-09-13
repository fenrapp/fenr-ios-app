import Foundation
import Observation
import WatchCompanionDomain

@MainActor
@Observable
public final class WatchDashboardViewModel {
    public private(set) var viewState = WatchDashboardViewState()
    private let observe: ObserveCompanionStateUseCase
    private let mapper: WatchDashboardViewStateMapper
    private let now: @Sendable () -> Date
    @ObservationIgnored private var state = CompanionState()
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    public init(
        observe: ObserveCompanionStateUseCase,
        mapper: WatchDashboardViewStateMapper,
        now: @escaping @Sendable () -> Date
    ) {
        self.observe = observe
        self.mapper = mapper
        self.now = now
    }

    deinit {
        observationTask?.cancel()
        refreshTask?.cancel()
    }

    public func start() {
        guard observationTask == nil else {
            update()
            observe.refresh()
            return
        }
        let stream = observe.execute()
        observationTask = Task { [weak self] in
            for await state in stream {
                guard !Task.isCancelled, let self else { return }
                self.state = state
                update()
            }
        }
        observe.refresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                guard !Task.isCancelled, let self else { return }
                update()
                observe.refresh()
            }
        }
    }

    public func stop() {
        observationTask?.cancel()
        observationTask = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func update() {
        viewState = mapper.map(state, now: now())
    }
}
