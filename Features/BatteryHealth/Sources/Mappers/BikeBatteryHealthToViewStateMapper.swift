import BikeDomain
import ChargeControl
import Foundation

@MainActor
public struct BikeBatteryHealthToViewStateMapper {
    let formatter: BatteryHealthFormatter
    let analyzer: BatteryHealthAnalyzer
    let captureFormatter: BatteryHealthCaptureFormatter
    let now: @Sendable () -> Date

    public init(
        formatter: BatteryHealthFormatter,
        analyzer: BatteryHealthAnalyzer,
        captureFormatter: BatteryHealthCaptureFormatter,
        now: @escaping @Sendable () -> Date
    ) {
        self.formatter = formatter
        self.analyzer = analyzer
        self.captureFormatter = captureFormatter
        self.now = now
    }

    public func map(
        health: BikeBatteryHealth,
        captures: [BatteryDataset: BatteryDatasetCapture],
        chargeControl: ChargeControlState = .init(),
        chargeAuditLines: [String] = [],
        isMonitoring: Bool,
        monitorError: String?
    ) -> BatteryHealthViewState {
        let analysis = analyzer.analyze(health)
        let summary = summaryMetrics(health: health, analysis: analysis, isMonitoring: isMonitoring)
        let stateOfHealthMetric = summary.first { $0.id == "soh" }
        let charging = chargingMetrics(for: health)
        let cells = cellViewData(for: analysis)
        let datasets = BatteryDataset.allCases.map {
            datasetViewData(dataset: $0, capture: captures[$0], health: health)
        }
        let control = mapChargeControl(chargeControl)
        return BatteryHealthViewState(
            overview: .init(
                status: overallStatus(health: health, analysis: analysis, monitorError: monitorError),
                statusDetail: statusDetail(health: health, analysis: analysis, monitorError: monitorError),
                stateOfHealthProgress: stateOfHealthProgress(health),
                stateOfHealthMetric: stateOfHealthMetric,
                summaryMetrics: summary.filter { $0.id != stateOfHealthMetric?.id },
                banners: banners(health: health, chargeControl: chargeControl, monitorError: monitorError)
            ),
            cellsDetail: .init(
                metrics: cellMetrics(for: analysis),
                distribution: distribution(for: analysis),
                cells: cells,
                balancingCount: analysis.balancingCellCount
            ),
            thermalDetail: thermalViewData(health: health, analysis: analysis),
            chargingDetail: .init(metrics: charging, control: control),
            rawDataDetail: .init(
                datasets: datasets,
                rawFlags: rawFlags(for: health),
                chargeAuditLines: chargeAuditLines
            ),
            isMonitoring: isMonitoring,
            monitorError: monitorError
        )
    }
}

extension BikeBatteryHealthToViewStateMapper {
    func metric(_ id: String, _ title: String, _ value: String) -> BatteryHealthMetricViewData {
        .init(id: id, title: title, value: value)
    }

    enum Constants {
        static let staleInterval: TimeInterval = 30
        static let millivoltsPerVolt = 1_000.0
        static let criticalDeviationVolts = 0.050
        static let thermalDomainStep = 10.0
        static let thermalDomainPadding = 5.0
    }
}
