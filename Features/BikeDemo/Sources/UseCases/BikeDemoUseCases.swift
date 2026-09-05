import BikeEmulator

public struct BikeDemoUseCases: Sendable {
    private let repository: BikeEmulatorRepository

    public init(repository: BikeEmulatorRepository) {
        self.repository = repository
    }

    func select(id: String) async -> BikeEmulatorScenario? {
        guard let scenario = BikeEmulatorScenario(rawValue: id),
              [.parked, .riding, .charging, .cellAnomaly].contains(scenario) else { return nil }
        await repository.setScenario(scenario)
        return await repository.currentScenario()
    }
}
