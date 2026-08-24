import Foundation

enum ChargingLiveActivityPreviewData {
    static let attributes = ChargingLiveActivityAttributes(vin: "DEBUG000000000000")

    static let charging = ChargingLiveActivityContentState(
        batteryPercent: 93,
        targetPercent: 100,
        estimatedTimeRemaining: "15m",
        powerText: "1.9 kW",
        currentText: "4.9 A",
        temperatureText: "25.7 °C",
        phase: .charging
    )

    static let balancing = ChargingLiveActivityContentState(
        batteryPercent: 100,
        targetPercent: 100,
        estimatedTimeRemaining: nil,
        powerText: "0.4 kW",
        currentText: "1.2 A",
        temperatureText: "27.1 °C",
        phase: .balancing
    )

    static let complete = ChargingLiveActivityContentState(
        batteryPercent: 100,
        targetPercent: 100,
        estimatedTimeRemaining: nil,
        powerText: nil,
        currentText: nil,
        temperatureText: "26.0 °C",
        phase: .complete
    )

    static let connectionLost = ChargingLiveActivityContentState(
        batteryPercent: 72,
        targetPercent: 90,
        estimatedTimeRemaining: nil,
        powerText: nil,
        currentText: nil,
        temperatureText: nil,
        phase: .connectionLost
    )
}
