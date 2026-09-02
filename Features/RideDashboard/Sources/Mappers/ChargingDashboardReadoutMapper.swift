import BikeDomain

struct ChargingDashboardReadoutInput: Sendable {
    let batteryPercent: Int?
    let targetPercent: Int?
    let estimatedTimeRemaining: String?
    let isBalancingAtFullCharge: Bool
    let hasReachedChargeLimit: Bool
    let isChargerConnected: Bool
    let batteryHealth: BikeBatteryHealth
}

public struct ChargingDashboardReadoutMapper: Sendable {
    public init() {}

    func map(_ input: ChargingDashboardReadoutInput) -> ChargingDashboardReadoutViewData {
        if let exceptional = exceptionalReadout(input) {
            return exceptional
        }
        let title: String
        let subtitle: String?
        if input.isBalancingAtFullCharge {
            title = "BALANCING"
            let count = input.batteryHealth.balancingCellIndexes.count
            subtitle = "\(count) \(count == 1 ? "CELL" : "CELLS") ACTIVE"
        } else if let estimatedTimeRemaining = input.estimatedTimeRemaining {
            title = "ETA: \(estimatedTimeRemaining)"
            subtitle = input.targetPercent.map { "TARGET \($0)%" }
        } else {
            title = "CHARGING"
            subtitle = input.targetPercent.map { "TARGET \($0)%" }
        }
        let chargeState = input.isBalancingAtFullCharge ? "Balancing" : "Charging"
        let chargeLevel = input.batteryPercent.map { "\($0) percent" } ?? "unavailable"
        let target = input.targetPercent.map { ". Target \($0) percent" } ?? ""
        return .init(
            title: title,
            subtitle: subtitle,
            accessibilityLabel: "\(chargeState) \(chargeLevel)\(target)",
            emphasis: input.isBalancingAtFullCharge ? .balancing : .charging,
            allowsControl: !input.isBalancingAtFullCharge
        )
    }

    private func exceptionalReadout(
        _ input: ChargingDashboardReadoutInput
    ) -> ChargingDashboardReadoutViewData? {
        guard !input.isBalancingAtFullCharge else { return nil }
        guard input.isChargerConnected else { return disconnected }
        guard input.batteryHealth.lastUpdated != nil,
              input.batteryHealth.chargeState != .unknown,
              input.batteryHealth.chargingStatus != nil else {
            return .init(
                title: "CHARGING",
                subtitle: "DATA UNAVAILABLE",
                accessibilityLabel: "Charging data unavailable",
                systemImage: "exclamationmark.triangle.fill",
                emphasis: .warning,
                allowsControl: false,
                showsProgress: false
            )
        }
        if input.hasReachedChargeLimit {
            return reachedLimitReadout(
                batteryPercent: input.batteryPercent,
                targetPercent: input.targetPercent
            )
        }
        guard input.batteryHealth.chargeState != .connected else {
            return .init(
                title: "CHARGER",
                subtitle: "CONNECTED · IDLE",
                accessibilityLabel: "Charger connected but not charging",
                systemImage: "powerplug.fill",
                emphasis: .warning,
                allowsControl: false,
                showsProgress: false
            )
        }
        guard input.batteryHealth.chargeState != .disconnected else { return disconnected }
        return nil
    }

    private var disconnected: ChargingDashboardReadoutViewData {
        .init(
            title: "CHARGER",
            subtitle: "DISCONNECTED",
            accessibilityLabel: "Charger disconnected",
            systemImage: "bolt.slash.fill",
            emphasis: .critical,
            allowsControl: false,
            showsProgress: false
        )
    }

    private func reachedLimitReadout(
        batteryPercent: Int?,
        targetPercent: Int?
    ) -> ChargingDashboardReadoutViewData {
        let batteryLevel = batteryPercent.map { "BATTERY \($0)%" }
        let target = targetPercent.map { "TARGET \($0)%" }
        let subtitle = [target, batteryLevel].compactMap { $0 }.joined(separator: " · ")
        return .init(
            title: "LIMIT REACHED",
            subtitle: subtitle.isEmpty ? nil : subtitle,
            accessibilityLabel: ["Charge limit reached", target, batteryLevel]
                .compactMap { $0 }
                .joined(separator: ". "),
            systemImage: "checkmark.circle.fill",
            emphasis: .charging,
            allowsControl: true
        )
    }
}
