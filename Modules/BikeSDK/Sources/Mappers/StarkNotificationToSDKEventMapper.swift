import Foundation
import StarkProtocol

public struct StarkNotificationToSDKEventMapper: Sendable {
    private let decoderRegistry: StarkNotificationDecoderRegistry

    public init(decoderRegistry: StarkNotificationDecoderRegistry) {
        self.decoderRegistry = decoderRegistry
    }

    public func telemetryPayload(characteristic: UUID, data: Data) throws -> BikeSDKTelemetryPayload? {
        try decoderRegistry.decode(characteristic: characteristic, data: data)
    }

    public func debug(
        characteristic: UUID,
        data: Data,
        payload: BikeSDKTelemetryPayload? = nil,
        date: Date
    ) -> BikeSDKNotificationDebug {
        BikeSDKNotificationDebug(
            characteristic: characteristic,
            byteCount: data.count,
            hex: data.bikeSDKHexString,
            decodedDetail: payload.map(decodedDetail),
            date: date
        )
    }

    private func decodedDetail(_ payload: BikeSDKTelemetryPayload) -> String {
        switch payload {
        case .batteryStatus(let value):
            return "positiveFaultBits=\(value.positiveFaultBits) "
                + "negativeFaultBits=\(value.negativeFaultBits)"
        case .battery(let value):
            let dcBus = value.dcBusRaw.map(String.init) ?? "nil"
            let dcBusVolts = value.dcBusVolts.map { String($0) } ?? "nil"
            let stateOfHealth = value.stateOfHealthPercent.map(String.init) ?? "nil"
            return "soc=\(value.stateOfChargePercent) soh=\(stateOfHealth) "
                + "dcBusRaw=\(dcBus) dcBusVolts=\(dcBusVolts) conversion=dcBusRaw/10"
        case .batteryParameters(let value):
            return "series=\(value.seriesCount) parallel=\(value.parallelCount) capacityRaw=\(value.capacityRaw)"
        case .batterySignals(let value):
            return "currentCandidateRaw=\(value.currentRaw) candidateA=\(value.currentCandidateAmperes) "
                + "pos=[\(bmsDetail(value.positive))] neg=[\(bmsDetail(value.negative))] "
                + "candidateFormula=electricalPowerW(latest6004.dcBusRaw/10*candidateA);"
                + "starkHP(electricalPowerW*0.0011)"
        case .liveEstimations(let value):
            return "rangeRaw=\(value.estimatedRangeRaw) timeRaw=\(value.estimatedTimeRaw) "
                + "motorPowerRaw=\(value.nativeMotorPowerRaw)"
        default:
            return String(describing: payload)
        }
    }

    private func bmsDetail(_ value: StarkBMSSignalsPayload) -> String {
        "voltageCandidateRaw=\(value.voltageCandidateRaw) "
            + "tempRaw=\(value.temperatureRaw) tempCandidateC=\(value.temperatureCelsius) "
            + "humidityRaw=\(value.humidityRaw) humidityCandidatePercent=\(value.humidityPercent) "
            + "control=\(value.controlFlags)"
    }
}
