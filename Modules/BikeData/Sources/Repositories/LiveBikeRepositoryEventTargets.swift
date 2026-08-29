import BikeDomain

struct LiveBikeRepositoryEventTargets: Sendable {
    let stateStore: BikeRepositoryStateStore
    let telemetryHub: AsyncEventHub<BikeTelemetry>
    let connectionHub: AsyncEventHub<BikeConnection>
    let debugHub: AsyncEventHub<BikeDebugEvent>
    let imuHub: AsyncEventHub<BikeIMUSample>
    let batteryHealthStore: BatteryHealthStateStore
    let batteryHealthHub: AsyncEventHub<BikeBatteryHealth>
    let batteryCaptureHub: AsyncEventHub<BatteryDatasetCapture>
    let discoveredBikesHub: AsyncEventHub<[DiscoveredBike]>
}
