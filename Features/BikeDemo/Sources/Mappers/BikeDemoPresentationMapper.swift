import BikeEmulator
import Foundation

public struct BikeDemoPresentationMapper: Sendable {
    public init() {}

    public func map(_ scenario: BikeEmulatorScenario) -> BikeDemoViewState {
        .init(scenarios: [
            .init(id: "parked", title: String(localized: .bikeDemoParked),
                  detail: String(localized: .bikeDemoParkedDetail), icon: "motorcycle"),
            .init(id: "riding", title: String(localized: .bikeDemoRiding),
                  detail: String(localized: .bikeDemoRidingDetail), icon: "speedometer"),
            .init(id: "charging", title: String(localized: .bikeDemoCharging),
                  detail: String(localized: .bikeDemoChargingDetail), icon: "bolt.fill"),
            .init(id: "cellAnomaly", title: String(localized: .bikeDemoBatteryIssue),
                  detail: String(localized: .bikeDemoBatteryIssueDetail), icon: "battery.25percent")
        ], selectedID: scenario.rawValue)
    }
}
