import Combine

@MainActor
public final class BikeDemoViewModel: ObservableObject {
    @Published public private(set) var viewState: BikeDemoViewState
    private let useCases: BikeDemoUseCases
    private let mapper: BikeDemoPresentationMapper
    private var selectionTask: Task<Void, Never>?

    public init(viewState: BikeDemoViewState, useCases: BikeDemoUseCases, mapper: BikeDemoPresentationMapper) {
        self.viewState = viewState
        self.useCases = useCases
        self.mapper = mapper
    }

    deinit { selectionTask?.cancel() }

    public func select(id: String) {
        let previous = selectionTask
        previous?.cancel()
        selectionTask = Task { [weak self, useCases, mapper] in
            await previous?.value
            guard !Task.isCancelled else { return }
            let scenario = await useCases.select(id: id)
            guard !Task.isCancelled, let scenario else { return }
            self?.viewState = mapper.map(scenario)
        }
    }

    public func stop() async {
        selectionTask?.cancel()
        await selectionTask?.value
        selectionTask = nil
    }
}
