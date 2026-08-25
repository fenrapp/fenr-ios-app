import BikeEmulator
import Combine

@MainActor
final class DebugScenarioController: ObservableObject {
    @Published private(set) var selectedScenario: BikeEmulatorScenario
    @Published private(set) var selectedPowerModePreset: BikeEmulatorPowerModePreset
    @Published private(set) var selectedMap: Int

    private let repository: BikeEmulatorRepository
    private let store: DebugScenarioStore
    private let profileRepository: DebugBikeProfileRepository
    private var scenarioTask: Task<Void, Never>?

    init(
        repository: BikeEmulatorRepository,
        store: DebugScenarioStore,
        profileRepository: DebugBikeProfileRepository = DebugBikeProfileRepository(),
        initialPowerModePreset: BikeEmulatorPowerModePreset = .standard,
        initialMap: Int = 4
    ) {
        self.repository = repository
        self.store = store
        self.profileRepository = profileRepository
        selectedScenario = store.load()
        selectedPowerModePreset = initialPowerModePreset
        selectedMap = initialMap
    }

    func select(_ preset: BikeEmulatorPowerModePreset) {
        guard preset != selectedPowerModePreset else { return }
        selectedPowerModePreset = preset
        store.save(preset)
        Task { [repository, profileRepository] in
            await repository.setPowerModePreset(preset)
            await profileRepository.apply(preset: preset)
        }
    }

    func selectMap(_ map: Int) {
        guard 1 ... 5 ~= map, map != selectedMap else { return }
        selectedMap = map
        store.saveActiveMap(map)
        Task { [repository] in await repository.setActiveMap(map) }
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
