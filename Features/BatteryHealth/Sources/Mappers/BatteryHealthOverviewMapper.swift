import BikeDomain
import ChargeControl
import Foundation

extension BikeBatteryHealthToViewStateMapper {
    func summaryMetrics(
        health: BikeBatteryHealth,
        analysis: BatteryHealthAnalysis,
        isMonitoring: Bool
    ) -> [BatteryHealthMetricViewData] {
        [
            metric("soh", String(localized: .batteryHealthMetricSoh), formatter.percent(health.stateOfHealth.percent)),
            metric("soc", String(localized: .batteryHealthMetricSoc), formatter.percent(health.stateOfCharge.percent)),
            metric("dcBus", String(localized: .batteryHealthMetricDcBus), formatter.voltage(health.dcBusVoltage.volts)),
            metric("cellDelta", String(localized: .batteryHealthMetricCellDelta), millivolts(analysis.cellDeltaVolts)),
            metric("charge", String(localized: .batteryHealthMetricCharge), formatter.chargeState(health.chargeState)),
            metric("updated", String(localized: .batteryHealthMetricUpdated), formatter.date(health.lastUpdated)),
            metric(
                "monitoring",
                String(localized: .batteryHealthMetricMonitoring),
                isMonitoring
                    ? String(localized: .batteryHealthStatusActive)
                    : String(localized: .batteryHealthStatusInactive)
            )
        ]
    }

    func stateOfHealthProgress(_ health: BikeBatteryHealth) -> Double? {
        health.stateOfHealth.percent.map { min(max(Double($0) / 100, 0), 1) }
    }

    func packMetrics(
        for health: BikeBatteryHealth,
        analysis: BatteryHealthAnalysis,
        captures: [BatteryDataset: BatteryDatasetCapture]
    ) -> [BatteryHealthMetricViewData] {
        [
            metric(
                "fault",
                String(localized: .batteryHealthMetricBmsFault),
                health.isBMSFaultActive
                    ? String(localized: .batteryHealthStatusActive)
                    : String(localized: .batteryHealthStatusClear)
            ),
            metric(
                "captured",
                String(localized: .batteryHealthMetricCapturedDatasets),
                "\(captures.count)/\(BatteryDataset.allCases.count)"
            ),
            metric(
                "cellDelta",
                String(localized: .batteryHealthMetricCellDelta),
                millivolts(analysis.cellDeltaVolts)
            )
        ]
    }

    func overallStatus(
        health: BikeBatteryHealth,
        analysis: BatteryHealthAnalysis,
        monitorError: String?
    ) -> BatteryHealthOverallStatus {
        if monitorError != nil { return .unavailable }
        if health.isFaultActive { return .critical }
        guard hasCompleteHealthAssessment(health) else { return .collecting }
        switch analysis.severity {
        case .attention: return .attention
        case .critical: return .critical
        case .healthy: return .healthy
        case .unknown: return .collecting
        }
    }

    func statusDetail(
        health: BikeBatteryHealth,
        analysis: BatteryHealthAnalysis,
        monitorError: String?
    ) -> String {
        if monitorError != nil {
            return String(localized: .batteryHealthOverviewDetailMonitoringUnavailable)
        }
        if health.isVehicleFaultActive {
            return String(localized: .batteryHealthOverviewDetailVehicleFault)
        }
        if health.isBMSFaultActive {
            return String(localized: .batteryHealthOverviewDetailBmsFault)
        }
        guard hasCompleteHealthAssessment(health) else {
            return String(localized: .batteryHealthOverviewDetailCollecting)
        }
        if analysis.criticalCellCount > 0 {
            return String(localized: .batteryHealthOverviewDetailCritical)
        }
        if analysis.attentionCellCount > 0 {
            return String(localized: .batteryHealthOverviewDetailAttention)
        }
        return String(localized: .batteryHealthOverviewDetailHealthy)
    }

    private func hasCompleteHealthAssessment(_ health: BikeBatteryHealth) -> Bool {
        health.lastUpdated != nil
            && health.stateOfHealth.percent != nil
            && !health.cellVoltages.isEmpty
    }

    func banners(
        health: BikeBatteryHealth,
        chargeControl: ChargeControlState,
        monitorError: String?
    ) -> [BatteryHealthBannerViewData] {
        var result: [BatteryHealthBannerViewData] = []
        if health.isVehicleFaultActive || health.isBMSFaultActive {
            result.append(.init(
                kind: .fault,
                title: String(localized: .batteryHealthBannerFaultTitle),
                message: health.isBMSFaultActive
                    ? String(localized: .batteryHealthBannerFaultBmsMessage)
                    : String(localized: .batteryHealthBannerFaultVehicleMessage),
                emphasis: .critical
            ))
        }
        if let updated = health.lastUpdated,
           now().timeIntervalSince(updated) > Constants.staleInterval {
            result.append(.init(
                kind: .stale,
                title: String(localized: .batteryHealthBannerDataStaleTitle),
                message: String(localized: .batteryHealthBannerDataStaleMessage),
                emphasis: .warning
            ))
        }
        if let monitorError {
            result.append(.init(
                kind: .monitoring,
                title: String(localized: .batteryHealthBannerMonitoringUnavailableTitle),
                message: monitorError,
                emphasis: .warning
            ))
        }
        if let failure = chargeControl.failure {
            result.append(.init(
                kind: .write,
                title: String(localized: .batteryHealthBannerChargeSettingFailedTitle),
                message: failureText(failure),
                emphasis: .critical
            ))
        }
        return result
    }
}
