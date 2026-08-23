import BikeEmulator
import Combine

@MainActor
final class DebugScenarioController: ObservableObject {
    @Published private(set) var selectedScenario: BikeEmulatorScenario

    private let repository: BikeEmulatorRepository
    private let store: DebugScenarioStore

    init(repository: BikeEmulatorRepository, store: DebugScenarioStore) {
        self.repository = repository
        self.store = store
        selectedScenario = store.load()
    }

    func select(_ scenario: BikeEmulatorScenario) {
        guard scenario != selectedScenario else { return }
        selectedScenario = scenario
        store.save(scenario)
        Task { await repository.setScenario(scenario) }
    }
}
