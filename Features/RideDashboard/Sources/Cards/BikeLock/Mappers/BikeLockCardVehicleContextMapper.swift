import SettingsDomain
import VehicleSession

struct BikeLockCardVehicleContext {
    let vehicleIdentifier: String?
    let settings: BikeLockSettings
    let isReceivingTelemetry: Bool
    let isStationary: Bool
}

public struct BikeLockCardVehicleContextMapper: Sendable {
    public init() {}

    func map(_ snapshot: VehicleSessionSnapshot) -> BikeLockCardVehicleContext {
        let rawVIN = snapshot.profile?.vin
        let vin = rawVIN?.isEmpty == false ? rawVIN : nil
        let receivesTelemetry = snapshot.isCanonicalTelemetryAvailable
        let speed = snapshot.resolvedSpeedKilometersPerHour
        let isStationary = receivesTelemetry
            && !snapshot.telemetry.statusFlags.isInGear
            && snapshot.telemetry.runState != .charging
            && speed?.isFinite == true
            && abs(speed ?? .infinity) < Constants.maximumStationarySpeed
        return .init(
            vehicleIdentifier: vin,
            settings: vin.map { snapshot.settings.bikeLockSettings(forVIN: $0) } ?? .init(),
            isReceivingTelemetry: receivesTelemetry,
            isStationary: isStationary
        )
    }

    private enum Constants {
        static let maximumStationarySpeed = 0.5
    }
}
