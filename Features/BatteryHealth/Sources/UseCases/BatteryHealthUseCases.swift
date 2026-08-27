import BikeDomain

public struct BatteryHealthUseCases: Sendable {
    public let observeCaptures: ObserveBatteryDatasetCapturesUseCase

    public init(observeCaptures: ObserveBatteryDatasetCapturesUseCase) {
        self.observeCaptures = observeCaptures
    }
}
