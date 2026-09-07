import BikeEmulator
import Observation

private enum DebugScenarioCommand: Sendable {
    case scenario(BikeEmulatorScenario)
    case powerModePreset(BikeEmulatorPowerModePreset)
    case activeMap(Int)
    case barrier(CheckedContinuation<Void, Never>)
}

@MainActor
@Observable
final class DebugScenarioController {
    private(set) var selectedScenario: BikeEmulatorScenario
    private(set) var selectedPowerModePreset: BikeEmulatorPowerModePreset
    private(set) var selectedMap: Int

    private let store: DebugScenarioStore
    private let commandContinuation: AsyncStream<DebugScenarioCommand>.Continuation
    private let commandTask: Task<Void, Never>

    init(
        repository: BikeEmulatorRepository,
        store: DebugScenarioStore,
        profileRepository: DebugBikeProfileRepository,
        initialPowerModePreset: BikeEmulatorPowerModePreset = .standard,
        initialMap: Int = 4
    ) {
        self.store = store
        selectedScenario = store.load()
        selectedPowerModePreset = initialPowerModePreset
        selectedMap = initialMap

        let (commands, continuation) = AsyncStream<DebugScenarioCommand>.makeStream(
            bufferingPolicy: .unbounded
        )
        commandContinuation = continuation
        commandTask = Task {
            for await command in commands {
                guard !Task.isCancelled else { return }
                switch command {
                case .scenario(let scenario):
                    await repository.setScenario(scenario)
                case .powerModePreset(let preset):
                    await repository.setPowerModePreset(preset)
                    await profileRepository.apply(preset: preset)
                case .activeMap(let map):
                    await repository.setActiveMap(map)
                case .barrier(let continuation):
                    continuation.resume()
                }
            }
        }
    }

    deinit {
        commandContinuation.finish()
        commandTask.cancel()
    }

    func select(_ preset: BikeEmulatorPowerModePreset) {
        guard preset != selectedPowerModePreset else { return }
        selectedPowerModePreset = preset
        store.save(preset)
        commandContinuation.yield(.powerModePreset(preset))
    }

    func selectMap(_ map: Int) {
        guard 1 ... 5 ~= map, map != selectedMap else { return }
        selectedMap = map
        store.saveActiveMap(map)
        commandContinuation.yield(.activeMap(map))
    }

    func select(_ scenario: BikeEmulatorScenario) {
        guard scenario != selectedScenario else { return }
        selectedScenario = scenario
        store.save(scenario)
        commandContinuation.yield(.scenario(scenario))
    }

    func waitForPendingCommands() async {
        await withCheckedContinuation { continuation in
            commandContinuation.yield(.barrier(continuation))
        }
    }
}
