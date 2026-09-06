import BikeDomain
import Foundation
import SettingsDomain
import VehicleSession

public struct SystemHealthCardMapper: Sendable {
    private let analyzer: BatteryHealthAnalyzer
    private let makeMeasurementMapper: @Sendable (MeasurementSystem) -> RideDashboardMeasurementMapper

    public init(
        analyzer: BatteryHealthAnalyzer = .init(),
        makeMeasurementMapper: @escaping @Sendable (MeasurementSystem) -> RideDashboardMeasurementMapper
    ) {
        self.analyzer = analyzer
        self.makeMeasurementMapper = makeMeasurementMapper
    }

    public func map(_ snapshot: VehicleSessionSnapshot) -> DashboardSystemHealthViewData {
        let analysis = analyzer.analyze(snapshot.batteryHealth)
        let measurementMapper = makeMeasurementMapper(snapshot.settings.measurementSystem)
        let status = status(snapshot.batteryHealthMonitoringState, analysis: analysis)
        let batteryThermalRange = analysis.batteryTemperatures.map {
            thermalRange($0, measurementMapper: measurementMapper)
        }
        let inverterThermalRange = thermalStatistics(snapshot.telemetry.inverterTemperaturesCelsius).map {
            thermalRange($0, measurementMapper: measurementMapper)
        }
        return DashboardSystemHealthViewData(
            status: status,
            statusText: statusText(status),
            statusDetail: statusDetail(status, analysis: analysis),
            stateOfHealthText: analysis.stateOfHealthPercent.map { "\($0)%" }
                ?? rideDashboardLocalized(.rideDashboardValueNotAvailable),
            stateOfHealthProgress: progress(analysis.stateOfHealthPercent),
            cellDeltaText: millivolts(analysis.cellDeltaVolts, measurementMapper: measurementMapper),
            dcBusVoltageText: voltage(snapshot.batteryHealth.dcBusVoltage.volts, measurementMapper: measurementMapper),
            batteryTemperatureText: batteryThermalRange?.maximumText ?? "—",
            inverterTemperatureText: inverterThermalRange?.maximumText ?? "—",
            criticalCellCount: analysis.criticalCellCount,
            attentionCellCount: analysis.attentionCellCount,
            balancingCellCount: analysis.balancingCellCount,
            cells: analysis.cells.map(cell),
            minimumCellText: cellSummary(analysis.minimumCell, measurementMapper: measurementMapper),
            maximumCellText: cellSummary(analysis.maximumCell, measurementMapper: measurementMapper),
            batteryThermalRange: batteryThermalRange,
            inverterThermalRange: inverterThermalRange
        )
    }
}

private extension SystemHealthCardMapper {
    func status(
        _ monitoringState: VehicleBatteryHealthMonitoringState,
        analysis: BatteryHealthAnalysis
    ) -> DashboardSystemHealthViewData.Status {
        if case .failed = monitoringState { return .unavailable }
        if analysis.isBMSFaultActive { return .critical }
        guard !analysis.cells.isEmpty else { return .scanning }
        if analysis.severity == .critical { return .critical }
        if analysis.isLowBattery { return .lowBattery }
        return switch analysis.severity {
        case .unknown: .scanning
        case .healthy: .healthy
        case .attention: .attention
        case .critical: .critical
        }
    }

    func statusText(_ status: DashboardSystemHealthViewData.Status) -> String {
        switch status {
        case .scanning: rideDashboardLocalized(.rideDashboardSystemHealthStatusScanning)
        case .healthy: rideDashboardLocalized(.rideDashboardCommonOk)
        case .lowBattery: rideDashboardLocalized(.rideDashboardSystemHealthStatusLowBatteryShort)
        case .attention: rideDashboardLocalized(.rideDashboardSystemHealthCellsCheck)
        case .critical: rideDashboardLocalized(.rideDashboardSystemHealthCellsCritical)
        case .unavailable: rideDashboardLocalized(.rideDashboardCommonUnavailable).uppercased()
        }
    }

    func statusDetail(
        _ status: DashboardSystemHealthViewData.Status,
        analysis: BatteryHealthAnalysis
    ) -> String {
        if analysis.isBMSFaultActive { return rideDashboardLocalized(.rideDashboardSystemHealthStatusBmsFault) }
        if analysis.criticalCellCount > .zero {
            return cellCountText(
                analysis.criticalCellCount,
                qualifier: rideDashboardLocalized(.rideDashboardSystemHealthCellsCritical)
            )
        }
        if status == .lowBattery { return rideDashboardLocalized(.rideDashboardSystemHealthStatusLowBattery) }
        if analysis.attentionCellCount > .zero {
            return cellCountText(
                analysis.attentionCellCount,
                qualifier: rideDashboardLocalized(.rideDashboardSystemHealthCellsToCheck)
            )
        }
        switch status {
        case .scanning: return ""
        case .healthy:
            return rideDashboardLocalized(
                analysis.balancingCellCount > .zero
                    ? .rideDashboardSystemHealthStatusBalancing
                    : .rideDashboardSystemHealthStatusNormal
            )
        case .lowBattery: return rideDashboardLocalized(.rideDashboardSystemHealthStatusLowBattery)
        case .attention: return rideDashboardLocalized(.rideDashboardSystemHealthStatusOutsideRange)
        case .critical: return rideDashboardLocalized(.rideDashboardSystemHealthStatusLimitExceeded)
        case .unavailable: return rideDashboardLocalized(.rideDashboardSystemHealthStatusDataUnavailable)
        }
    }

    func cellCountText(_ count: Int, qualifier: String) -> String {
        rideDashboardLocalized(.rideDashboardSystemHealthCellCountQualifier(count, qualifier))
    }

    func progress(_ percent: Int?) -> Double {
        guard let percent else { return .zero }
        return min(max(Double(percent) / Constants.percentageScale, .zero), 1)
    }

    func cell(
        _ assessment: BatteryCellHealthAssessment
    ) -> DashboardSystemHealthViewData.Cell {
        .init(
            position: assessment.position,
            condition: cellCondition(assessment.condition),
            isBalancing: assessment.isBalancing
        )
    }

    func cellCondition(_ condition: BatteryCellHealthCondition) -> DashboardSystemHealthViewData.CellCondition {
        switch condition {
        case .normal: .normal
        case .belowAverage: .belowAverage
        case .aboveAverage: .aboveAverage
        case .critical: .critical
        }
    }

    func cellSummary(
        _ cell: BatteryCellVoltage?,
        measurementMapper: RideDashboardMeasurementMapper
    ) -> String {
        guard let cell else { return "—" }
        return "#\(cell.position) · \(voltage(cell.volts, fractionDigits: 4, measurementMapper: measurementMapper))"
    }

    func voltage(
        _ volts: Double?,
        fractionDigits: Int = 1,
        measurementMapper: RideDashboardMeasurementMapper
    ) -> String {
        guard let volts, volts.isFinite else { return "—" }
        return measurementMapper.number(volts, fractionDigits: fractionDigits) + " V"
    }

    func millivolts(
        _ volts: Double?,
        measurementMapper: RideDashboardMeasurementMapper
    ) -> String {
        guard let volts, volts.isFinite else { return "—" }
        return measurementMapper.number(volts * Constants.millivoltsPerVolt, fractionDigits: .zero) + " mV"
    }

    func thermalStatistics(_ values: [Double?]) -> BatteryTemperatureStatistics? {
        let temperatures = values.compactMap { $0 }.filter(\.isFinite)
        guard let minimum = temperatures.min(), let maximum = temperatures.max() else { return nil }
        return .init(
            minimumCelsius: minimum,
            averageCelsius: temperatures.reduce(.zero, +) / Double(temperatures.count),
            maximumCelsius: maximum
        )
    }

    func thermalRange(
        _ statistics: BatteryTemperatureStatistics,
        measurementMapper: RideDashboardMeasurementMapper
    ) -> DashboardSystemHealthViewData.ThermalRange {
        .init(
            minimumCelsius: statistics.minimumCelsius,
            averageCelsius: statistics.averageCelsius,
            maximumCelsius: statistics.maximumCelsius,
            minimumText: temperature(statistics.minimumCelsius, measurementMapper: measurementMapper),
            averageText: temperature(statistics.averageCelsius, measurementMapper: measurementMapper),
            maximumText: temperature(statistics.maximumCelsius, measurementMapper: measurementMapper)
        )
    }

    func temperature(_ celsius: Double, measurementMapper: RideDashboardMeasurementMapper) -> String {
        let measurement = measurementMapper.temperature(celsius: celsius)
        return measurementMapper.number(measurement.value, fractionDigits: .zero) + measurement.unit
    }

    enum Constants {
        static let percentageScale = 100.0
        static let millivoltsPerVolt = 1_000.0
    }
}
