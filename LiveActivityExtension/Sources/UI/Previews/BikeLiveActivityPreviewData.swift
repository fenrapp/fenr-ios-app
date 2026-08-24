import Foundation

enum BikeLiveActivityPreviewData {
    static let attributes = BikeLiveActivityAttributes(vin: "DEBUG000000000000")

    static let charging = BikeLiveActivityContentState(
        batteryPercent: 93,
        targetPercent: 100,
        estimatedTimeRemaining: "15m",
        powerText: "1.9 kW",
        currentText: "4.9 A",
        temperatureText: "25.7 °C",
        modeIndex: nil,
        speedText: nil,
        runState: .charging,
        mode: .charging,
        phase: .charging,
        isFaultActive: false,
        isConnectionLost: false
    )

    static let balancing = BikeLiveActivityContentState(
        batteryPercent: 100,
        targetPercent: 100,
        estimatedTimeRemaining: nil,
        powerText: "0.4 kW",
        currentText: "1.2 A",
        temperatureText: "27.1 °C",
        modeIndex: nil,
        speedText: nil,
        runState: .charging,
        mode: .charging,
        phase: .balancing,
        isFaultActive: false,
        isConnectionLost: false
    )

    static let complete = BikeLiveActivityContentState(
        batteryPercent: 100,
        targetPercent: 100,
        estimatedTimeRemaining: nil,
        powerText: nil,
        currentText: nil,
        temperatureText: "26.0 °C",
        modeIndex: nil,
        speedText: nil,
        runState: .charging,
        mode: .charging,
        phase: .complete,
        isFaultActive: false,
        isConnectionLost: false
    )

    static let riding = BikeLiveActivityContentState(
        batteryPercent: 72,
        targetPercent: nil,
        estimatedTimeRemaining: nil,
        powerText: nil,
        currentText: nil,
        temperatureText: nil,
        modeIndex: 3,
        speedText: "48 km/h",
        runState: .ride,
        mode: .riding,
        phase: .riding,
        isFaultActive: false,
        isConnectionLost: false
    )

    static let ridingLowBattery = BikeLiveActivityContentState(
        batteryPercent: 14,
        targetPercent: nil,
        estimatedTimeRemaining: nil,
        powerText: nil,
        currentText: nil,
        temperatureText: nil,
        modeIndex: 2,
        speedText: "31 km/h",
        runState: .ride,
        mode: .riding,
        phase: .riding,
        isFaultActive: false,
        isConnectionLost: false
    )

    static let fault = BikeLiveActivityContentState(
        batteryPercent: 48,
        targetPercent: nil,
        estimatedTimeRemaining: nil,
        powerText: nil,
        currentText: nil,
        temperatureText: nil,
        modeIndex: 1,
        speedText: "0 km/h",
        runState: .neutral,
        mode: .riding,
        phase: .fault,
        isFaultActive: true,
        isConnectionLost: false
    )

    static let connectionLost = BikeLiveActivityContentState(
        batteryPercent: 72,
        targetPercent: nil,
        estimatedTimeRemaining: nil,
        powerText: nil,
        currentText: nil,
        temperatureText: nil,
        modeIndex: 3,
        speedText: "48 km/h",
        runState: .ride,
        mode: .connectionLost,
        phase: .connectionLost,
        isFaultActive: false,
        isConnectionLost: true
    )
}
