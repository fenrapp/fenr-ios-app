import BikeDomain
import Foundation
import SettingsDomain

public struct ChargingTimeRemainingEstimator: Sendable {
    private let formatStyle: Duration.UnitsFormatStyle
    private let batteryPackCapacity: BatteryPackCapacity

    public init(
        formatStyle: Duration.UnitsFormatStyle,
        batteryPackCapacity: BatteryPackCapacity
    ) {
        self.formatStyle = formatStyle
        self.batteryPackCapacity = batteryPackCapacity
    }

    func estimate(
        stateOfCharge: Int?,
        targetPercent: Int?,
        batteryVoltage: Double?,
        status: BikeChargingStatus?
    ) -> String? {
        guard let stateOfCharge,
              let targetPercent,
              let batteryVoltage,
              let status,
              targetPercent > stateOfCharge,
              batteryVoltage > .zero,
              status.reportedCurrentAmperes > .zero else { return nil }
        let remainingEnergy = Double(targetPercent - stateOfCharge)
            / Constants.percentageScale * batteryPackCapacity.wattHours
        let remainingSeconds = remainingEnergy
            / (batteryVoltage * status.reportedCurrentAmperes) * Constants.secondsPerHour
        guard remainingSeconds.isFinite, remainingSeconds > .zero else { return nil }
        return Duration.seconds(remainingSeconds).formatted(formatStyle)
    }

    private enum Constants {
        static let percentageScale = 100.0
        static let secondsPerHour = 3_600.0
    }
}
