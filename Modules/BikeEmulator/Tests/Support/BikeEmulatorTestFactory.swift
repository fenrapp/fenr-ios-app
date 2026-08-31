@testable import BikeEmulator

struct BikeEmulatorTestFixture {
    let repository: BikeEmulatorRepository
    let runtime: ControllableBikeEmulatorRuntime
}

func makeBikeEmulatorTestFixture(
    scenario: BikeEmulatorScenario = .charging,
    powerModePreset: BikeEmulatorPowerModePreset = .standard,
    activeMap: Int = 4
) async -> BikeEmulatorTestFixture {
    let runtime = ControllableBikeEmulatorRuntime()
    let repository = BikeEmulatorRepositoryFactory.make(
        scenario: scenario,
        powerModePreset: powerModePreset,
        activeMap: activeMap,
        runtime: await runtime.makeRuntime()
    )
    return BikeEmulatorTestFixture(repository: repository, runtime: runtime)
}
