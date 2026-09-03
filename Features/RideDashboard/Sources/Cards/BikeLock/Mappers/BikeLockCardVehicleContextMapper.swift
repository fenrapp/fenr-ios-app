import SettingsDomain
import VehicleSession

struct BikeLockCardVehicleContext {
    let vehicleIdentifier: String?
    let settings: BikeLockSettings
    let isReceivingTelemetry: Bool
    let canPrepareNoOp: Bool
    let canPerformLockWrite: Bool
}

public struct BikeLockCardVehicleContextMapper: Sendable {
    public init() {}

    func map(_ snapshot: VehicleSessionSnapshot) -> BikeLockCardVehicleContext {
        let rawVIN = snapshot.profile?.vin
        let vin = rawVIN?.isEmpty == false ? rawVIN : nil
        let receivesTelemetry = snapshot.isCanonicalTelemetryAvailable
        let speed = snapshot.resolvedSpeedKilometersPerHour
        let isStopped = receivesTelemetry
            && !snapshot.telemetry.statusFlags.isInGear
            && speed?.isFinite == true
            && abs(speed ?? .infinity) < Constants.maximumStationarySpeed
        return .init(
            vehicleIdentifier: vin,
            settings: vin.map { snapshot.settings.bikeLockSettings(forVIN: $0) } ?? .init(),
            isReceivingTelemetry: receivesTelemetry,
            canPrepareNoOp: isStopped,
            canPerformLockWrite: isStopped && snapshot.telemetry.runState != .charging
        )
    }

    private enum Constants {
        static let maximumStationarySpeed = 0.5
    }
}
