import BikeDomain
import Foundation

extension BikeEmulatorRepository {
    public func readBikeLockFirmwareCompatibility() -> BikeLockFirmwareCompatibility {
        .init(firmware: "1.6.29", isCompatible: true)
    }

    public func prepareBikeLockControl() async throws -> BikeLockControlSnapshot {
        isBikeLockPrepared = true
        await publishDebugEvent(title: "Bike Lock", detail: "Debug no-op confirmed")
        return bikeLockSnapshot()
    }

    public func setBikeLocked(_ isLocked: Bool) async throws -> BikeLockControlSnapshot {
        guard isBikeLockPrepared else {
            throw BikeEmulatorBikeLockError.controlNotPrepared
        }
        isBikeLocked = isLocked
        await publishDebugEvent(
            title: "Bike Lock",
            detail: "Debug write confirmed state=\(isLocked)"
        )
        return bikeLockSnapshot()
    }

    private func bikeLockSnapshot() -> BikeLockControlSnapshot {
        .init(
            vcuFirmware: "1.6.29",
            isLocked: isBikeLocked,
            didPassNoOpWrite: isBikeLockPrepared
        )
    }
}

private enum BikeEmulatorBikeLockError: LocalizedError {
    case controlNotPrepared

    var errorDescription: String? {
        "Bike Lock control has not passed its debug no-op"
    }
}
