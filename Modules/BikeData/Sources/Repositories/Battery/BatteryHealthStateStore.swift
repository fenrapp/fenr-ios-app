import BikeDomain

public actor BatteryHealthStateStore {
    private var health = BikeBatteryHealth()
    private var captures: [BatteryDataset: BatteryDatasetCapture] = [:]

    public init() {}

    public func currentHealth() -> BikeBatteryHealth {
        health
    }

    public func currentCaptures() -> [BatteryDatasetCapture] {
        BatteryDataset.allCases.compactMap { captures[$0] }
    }

    public func updateHealth(_ update: (inout BikeBatteryHealth) -> Void) -> BikeBatteryHealth {
        update(&health)
        return health
    }

    public func storeCapture(_ capture: BatteryDatasetCapture) {
        captures[capture.dataset] = capture
    }

    public func reset() {
        health = BikeBatteryHealth()
        captures.removeAll()
    }
}
