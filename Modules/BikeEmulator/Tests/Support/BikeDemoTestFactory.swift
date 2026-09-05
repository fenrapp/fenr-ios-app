import BikeDomain
@testable import BikeEmulator
import Foundation

func makeDemoRepository(state: BikeEmulatorState = .init()) -> BikeEmulatorRepository {
    BikeEmulatorRepositoryFactory.make(configuration: .init(
        vin: "FENRTEST000000001", peripheralIdentifier: UUID(), initialState: state,
        isDemo: true, persist: { _ in }
    ))
}
