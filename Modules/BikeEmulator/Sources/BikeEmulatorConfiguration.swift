import Foundation

public struct BikeEmulatorConfiguration: Sendable {
    public let vin: String
    public let peripheralIdentifier: UUID
    public let initialState: BikeEmulatorState
    public let isDemo: Bool
    public let persist: @Sendable (BikeEmulatorState) -> Void

    public init(
        vin: String,
        peripheralIdentifier: UUID,
        initialState: BikeEmulatorState,
        isDemo: Bool,
        persist: @escaping @Sendable (BikeEmulatorState) -> Void
    ) {
        self.vin = vin
        self.peripheralIdentifier = peripheralIdentifier
        self.initialState = initialState
        self.isDemo = isDemo
        self.persist = persist
    }
}
