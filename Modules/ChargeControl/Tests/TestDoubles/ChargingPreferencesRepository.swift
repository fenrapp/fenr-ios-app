import BikeDomain
import Foundation
import TestSupport

actor ChargingPreferencesRepository: BikeChargePowerControlRepository {
    var watts = 1_200
    var target = 80
    var writes: [String] = []
    var reads = 0
    var compatible = true
    var failsPower = false
    var ignoresTarget = false
    var waitsForTarget = false
    let targetEvents = TestEventHub<Bool>(bufferingPolicy: .unbounded)

    func configure(
        compatible: Bool = true, failsPower: Bool = false,
        ignoresTarget: Bool = false, waitsForTarget: Bool = false
    ) {
        self.compatible = compatible
        self.failsPower = failsPower
        self.ignoresTarget = ignoresTarget
        self.waitsForTarget = waitsForTarget
    }

    func readChargeConfiguration() async throws -> BikeChargePowerControlSnapshot {
        reads += 1
        return snapshot()
    }

    func applyChargePower(watts: Int, chargerType: BikeChargerType) async throws -> BikeChargePowerControlSnapshot {
        writes.append("power:\(watts)")
        if failsPower { throw BikeChargingPreferencesError.invalidValues }
        self.watts = watts
        return snapshot()
    }

    func applyChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        writes.append("target:\(percent)")
        if waitsForTarget {
            let stream = await targetEvents.stream()
            for await _ in stream { break }
        }
        if !ignoresTarget { target = percent }
        return snapshot()
    }

    private func snapshot() -> BikeChargePowerControlSnapshot {
        .init(
            vcuFirmware: "1.12.0", isFirmwareCompatible: compatible,
            readRequestHex: "", readResponseHex: "",
            parsedConfig: .init(
                chargeCurrentDeciAmperes: 200, chargePowerWatts: watts,
                maximumStateOfChargeDeciPercent: target * 10,
                standardChargerMaximumPowerWatts: 3_300, backpackChargerMaximumPowerWatts: 3_300
            ),
            lastWriteHex: nil, didPassNoOpWrite: true, logLines: []
        )
    }
}
