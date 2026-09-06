import SwiftUI

#Preview("Battery cells - populated") {
    NavigationStack {
        BatteryHealthCellsView(state: BatteryDetailPreviewData.cells)
            .navigationTitle("Cells")
    }
}

#Preview("Battery cells - awaiting data") {
    NavigationStack { BatteryHealthCellsView(state: .init()) }
}

#Preview("Battery temperatures - populated") {
    NavigationStack {
        BatteryHealthThermalView(state: BatteryDetailPreviewData.thermal)
            .navigationTitle("Temperatures")
    }
}

#Preview("Battery temperatures - awaiting data") {
    NavigationStack { BatteryHealthThermalView(state: .init()) }
}

#Preview("Battery charging - supported") {
    NavigationStack {
        BatteryHealthChargingView(
            state: .init(
                metrics: [.init(id: "power", title: "Power", value: "2,000 W")],
                control: .init(
                    isVisible: true, isEnabled: true,
                    power: .init(selected: 2_000, minimum: 300, maximum: 3_300, step: 100),
                    target: .init(selected: 90, minimum: 1, maximum: 100, step: 1),
                    chargerText: "Standard charger", statusText: "Ready"
                )
            ),
            setPowerLimit: { _ in }, setChargeTarget: { _ in }
        )
        .navigationTitle("Charging")
    }
}

#Preview("Battery charging - unavailable - large text") {
    NavigationStack {
        BatteryHealthChargingView(state: .init(), setPowerLimit: { _ in }, setChargeTarget: { _ in })
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Battery raw data - populated") {
    NavigationStack {
        BatteryHealthRawDataView(state: BatteryDetailPreviewData.rawData, exportText: "Synthetic preview export")
            .navigationTitle("Raw data")
    }
}

#Preview("Battery raw data - awaiting data") {
    NavigationStack { BatteryHealthRawDataView(state: .init(), exportText: "") }
}

private enum BatteryDetailPreviewData {
    static let cells = BatteryHealthCellsViewData(
        metrics: [
            .init(id: "minimum", title: "Minimum", value: "#1 - 3.800 V"),
            .init(id: "maximum", title: "Maximum", value: "#3 - 3.900 V"),
            .init(id: "delta", title: "Delta", value: "100 mV")
        ],
        distribution: .init(normalCount: 1, attentionCount: 1, criticalCount: 1),
        cells: [
            .init(
                position: 1, voltage: "3.800 V", deviation: "-50 mV", condition: .critical,
                isBalancing: false, isMinimum: true, isMaximum: false,
                deviationProgress: -1, deviationMillivolts: -50
            ),
            .init(
                position: 2, voltage: "3.850 V", deviation: "0 mV", condition: .normal,
                isBalancing: true, isMinimum: false, isMaximum: false
            ),
            .init(
                position: 3, voltage: "3.900 V", deviation: "+50 mV", condition: .aboveAverage,
                isBalancing: false, isMinimum: false, isMaximum: true,
                deviationProgress: 1, deviationMillivolts: 50
            )
        ],
        balancingCount: 1
    )

    static let thermal = BatteryHealthThermalViewData(
        metrics: [
            .init(id: "minimum", title: "Minimum", value: "24 C"),
            .init(id: "average", title: "Average", value: "28 C"),
            .init(id: "maximum", title: "Maximum", value: "32 C")
        ],
        sensors: [.init(position: 1, value: "24 C"), .init(position: 2, value: "32 C")],
        valueRangeCelsius: 24 ... 32,
        averageCelsius: 28,
        displayDomainCelsius: 20 ... 40,
        emphasis: .positive
    )

    static let rawData = BatteryHealthRawDataViewData(
        datasets: [
            .init(
                id: "cellVoltages", title: "Cell voltages",
                status: .init(text: "Decoded", emphasis: .positive), state: .decoded,
                timestamp: "10:42:15", byteCount: 4, hex: "00 00 00 00"
            ),
            .init(
                id: "temperatures", title: "Temperatures",
                status: .init(text: "Awaiting sample", emphasis: .neutral)
            )
        ],
        rawFlags: [.init(id: "bms", title: "BMS flags", value: "0x0000")],
        chargeAuditLines: ["Preview: charge target confirmed at 90%"]
    )
}
