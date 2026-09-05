@testable import BikeEmulator
import BLETraceDomain

struct BikeEmulatorTestFixture {
    let repository: BikeEmulatorRepository
    let runtime: ControllableBikeEmulatorRuntime
}

func makeBikeEmulatorTestFixture(
    scenario: BikeEmulatorScenario = .charging,
    powerModePreset: BikeEmulatorPowerModePreset = .standard,
    activeMap: Int = 4,
    capturesDiagnostics: Bool = false
) async -> BikeEmulatorTestFixture {
    let runtime = ControllableBikeEmulatorRuntime()
    let captureState = BLETraceCaptureState()
    captureState.setRecording(capturesDiagnostics)
    let repository = BikeEmulatorRepositoryFactory.make(
        scenario: scenario,
        powerModePreset: powerModePreset,
        activeMap: activeMap,
        runtime: await runtime.makeRuntime(),
        diagnostics: BikeEmulatorDiagnostics(
            recorder: NoOpBLETraceRepository(), captureState: captureState, uptimeNanoseconds: { 1_000_000 }
        )
    )
    return BikeEmulatorTestFixture(repository: repository, runtime: runtime)
}
