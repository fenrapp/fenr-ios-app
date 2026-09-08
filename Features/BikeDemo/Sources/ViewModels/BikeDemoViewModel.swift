import Observation

@MainActor
@Observable
public final class BikeDemoViewModel {
    public private(set) var viewState: BikeDemoViewState
    private let useCases: BikeDemoUseCases
    private let mapper: BikeDemoPresentationMapper
    @ObservationIgnored private var selectionTask: Task<Void, Never>?
    @ObservationIgnored private var selectionGeneration: UInt = 0

    public init(viewState: BikeDemoViewState, useCases: BikeDemoUseCases, mapper: BikeDemoPresentationMapper) {
        self.viewState = viewState
        self.useCases = useCases
        self.mapper = mapper
    }

    deinit { selectionTask?.cancel() }

    public func select(id: String) {
        let previous = selectionTask
        previous?.cancel()
        selectionGeneration &+= 1
        selectionTask = Task { [weak self, useCases, mapper] in
            await previous?.value
            guard !Task.isCancelled else { return }
            let scenario = await useCases.select(id: id)
            guard !Task.isCancelled, let scenario else { return }
            self?.viewState = mapper.map(scenario)
        }
    }

    public func stop() async {
        let task = selectionTask
        let generation = selectionGeneration
        task?.cancel()
        await task?.value
        guard selectionGeneration == generation else { return }
        selectionTask = nil
    }
}
