import BikeEmulator
import Combine

@MainActor
final class DebugScenarioController: ObservableObject {
    @Published private(set) var selectedScenario: BikeEmulatorScenario

    private let repository: BikeEmulatorRepository
    private let store: DebugScenarioStore
    private var scenarioTask: Task<Void, Never>?

    init(repository: BikeEmulatorRepository, store: DebugScenarioStore) {
        self.repository = repository
        self.store = store
        selectedScenario = store.load()
    }

    deinit {
        scenarioTask?.cancel()
    }

    func select(_ scenario: BikeEmulatorScenario) {
        guard scenario != selectedScenario else { return }
        selectedScenario = scenario
        store.save(scenario)
        let previousSelection = scenarioTask
        scenarioTask = Task { [repository] in
            await previousSelection?.value
            guard !Task.isCancelled else { return }
            await repository.setScenario(scenario)
        }
    }
}
