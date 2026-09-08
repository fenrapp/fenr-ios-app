@testable import BikeDemo
@testable import BikeEmulator
import Foundation

@MainActor
struct BikeDemoTestFixture {
    let gate: BikeDemoSelectionGate
    let recorder: BikeDemoSelectionRecorder
    let repository: BikeEmulatorRepository
    let model: BikeDemoViewModel

    static func make() -> Self {
        let gate = BikeDemoSelectionGate()
        let recorder = BikeDemoSelectionRecorder()
        let configuration = BikeEmulatorConfiguration(
            vin: "FENRTEST000000001",
            peripheralIdentifier: UUID(),
            initialState: BikeEmulatorState(scenario: .parked, powerModePreset: .standard),
            isDemo: false,
            persist: { recorder.record($0.scenario) }
        )
        let runtime = BikeEmulatorRuntime(
            now: { await gate.now() },
            sleep: { try await Task.sleep(for: $0) },
            telemetryInterval: .seconds(1),
            imuInterval: .milliseconds(100)
        )
        let repository = BikeEmulatorRepositoryFactory.make(
            scenario: .parked, powerModePreset: .standard, activeMap: 4,
            runtime: runtime, configuration: configuration
        )
        let mapper = BikeDemoPresentationMapper()
        let model = BikeDemoViewModel(
            viewState: mapper.map(.parked), useCases: BikeDemoUseCases(repository: repository), mapper: mapper
        )
        return Self(gate: gate, recorder: recorder, repository: repository, model: model)
    }
}
