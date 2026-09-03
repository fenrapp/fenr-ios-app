import BikeDomain
import Foundation

extension BikeBatteryHealthToViewStateMapper {
    func datasetViewData(
        dataset: BatteryDataset,
        capture: BatteryDatasetCapture?,
        health: BikeBatteryHealth
    ) -> BatteryHealthDatasetViewData {
        let state: BatteryHealthDatasetViewData.State
        if isDecoded(dataset: dataset, health: health, capture: capture) {
            state = .decoded
        } else if capture != nil {
            state = .capturedOnly
        } else {
            state = .awaiting
        }
        let status = switch state {
        case .awaiting:
            BatteryHealthStatusViewData(
                text: String(localized: .batteryHealthDatasetStatusAwaiting),
                emphasis: .neutral
            )
        case .capturedOnly:
            BatteryHealthStatusViewData(
                text: String(localized: .batteryHealthDatasetStatusCapturedOnly),
                emphasis: .warning
            )
        case .decoded:
            BatteryHealthStatusViewData(
                text: String(localized: .batteryHealthDatasetStatusDecoded),
                emphasis: .positive
            )
        }
        return .init(
            id: dataset.rawValue,
            title: dataset.displayName,
            status: status,
            state: state,
            timestamp: captureFormatter.timestamp(capture?.date),
            byteCount: capture?.byteCount,
            hex: capture?.hex
        )
    }

    func isDecoded(
        dataset: BatteryDataset,
        health: BikeBatteryHealth,
        capture: BatteryDatasetCapture?
    ) -> Bool {
        switch dataset {
        case .cellVoltages: return !health.cellVoltages.isEmpty
        case .temperatures: return !health.temperatures.isEmpty
        case .balancing: return !health.cellVoltages.isEmpty && capture != nil
        case .bmsStatus: return capture != nil && health.lastUpdated != nil
        case .dcBus: return health.dcBusVoltage != .unknown
        case .signals: return health.chargeState != .unknown || health.isVehicleFaultActive
        case .charger: return health.chargingStatus != nil
        }
    }

    func rawFlags(for health: BikeBatteryHealth) -> [BatteryHealthMetricViewData] {
        [
            metric(
                "positiveBMSFaultBits",
                String(localized: .batteryHealthMetricPositiveBmsFaultBits),
                hex(health.positiveBMSFaultBits)
            ),
            metric(
                "negativeBMSFaultBits",
                String(localized: .batteryHealthMetricNegativeBmsFaultBits),
                hex(health.negativeBMSFaultBits)
            ),
            metric(
                "vehicleFault",
                String(localized: .batteryHealthMetricVehicleFault),
                health.isVehicleFaultActive ? "1" : "0"
            )
        ]
    }

    func hex(_ value: UInt32) -> String {
        String(format: "0x%08X", value)
    }
}
