import EnvironmentDomain
import TestSupport

actor VehicleSessionTestHeadingRepository: DeviceHeadingRepository {
    let hub: TestEventHub<DeviceHeadingSample>
    private(set) var subscriptions = 0

    init(hub: TestEventHub<DeviceHeadingSample>) { self.hub = hub }

    func observeDeviceHeading() async -> AsyncStream<DeviceHeadingSample> {
        subscriptions += 1
        return await hub.stream()
    }

    func send(_ value: DeviceHeadingSample) async { await hub.send(value) }
}
