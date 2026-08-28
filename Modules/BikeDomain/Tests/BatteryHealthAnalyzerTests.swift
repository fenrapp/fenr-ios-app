@testable import BikeDomain
import Testing

@Suite("Battery health analyzer")
struct BatteryHealthAnalyzerTests {
    private let analyzer = BatteryHealthAnalyzer()

    @Test("Uses conservative state of health boundaries", arguments: [
        (80, BatteryHealthSeverity.healthy),
        (79, BatteryHealthSeverity.attention),
        (70, BatteryHealthSeverity.attention),
        (69, BatteryHealthSeverity.critical)
    ])
    func stateOfHealthBoundaries(percent: Int, expected: BatteryHealthSeverity) {
        let analysis = analyzer.analyze(health(
            stateOfHealth: percent,
            cells: [.init(position: 1, volts: 3.9), .init(position: 2, volts: 3.9)]
        ))

        #expect(analysis.severity == expected)
    }

    @Test("Uses exact pack delta boundaries", arguments: [
        (0.019, BatteryHealthSeverity.healthy),
        (0.020, BatteryHealthSeverity.attention),
        (0.049, BatteryHealthSeverity.attention),
        (0.050, BatteryHealthSeverity.critical)
    ])
    func cellDeltaBoundaries(delta: Double, expected: BatteryHealthSeverity) {
        let analysis = analyzer.analyze(health(cells: [
            .init(position: 1, volts: 3.9),
            .init(position: 2, volts: 3.9 + delta)
        ]))

        #expect(abs((analysis.cellDeltaVolts ?? .zero) - delta) < 0.000_000_001)
        #expect(analysis.severity == expected)
    }

    @Test("Marks absolute voltage and deviation failures as critical")
    func criticalCells() {
        var cells = (1 ... 99).map { BatteryCellVoltage(position: $0, volts: 3.9) }
        cells.append(.init(position: 100, volts: 2.99))
        let analysis = analyzer.analyze(health(cells: cells))

        #expect(analysis.severity == .critical)
        #expect(analysis.criticalCellCount == 1)
        #expect(analysis.minimumCell?.position == 100)
    }

    @Test("Evaluates battery temperature boundaries", arguments: [
        (10.0, BatteryHealthSeverity.healthy),
        (9.9, BatteryHealthSeverity.attention),
        (4.0, BatteryHealthSeverity.attention),
        (3.9, BatteryHealthSeverity.critical),
        (49.9, BatteryHealthSeverity.healthy),
        (50.0, BatteryHealthSeverity.attention),
        (60.0, BatteryHealthSeverity.critical)
    ])
    func temperatureBoundaries(celsius: Double, expected: BatteryHealthSeverity) {
        let analysis = analyzer.analyze(health(
            cells: [.init(position: 1, volts: 3.9), .init(position: 2, volts: 3.9)],
            temperatures: [.init(position: 1, celsius: celsius)]
        ))

        #expect(analysis.severity == expected)
    }

    @Test("Ignores non-finite values and maps zero-based balancing indexes")
    func filtersInvalidValues() {
        let analysis = analyzer.analyze(health(
            cells: [
                .init(position: 1, volts: .nan),
                .init(position: 2, volts: 3.9),
                .init(position: 3, volts: .infinity)
            ],
            balancingIndexes: [1],
            temperatures: [
                .init(position: 1, celsius: .nan),
                .init(position: 2, celsius: 25)
            ]
        ))

        #expect(analysis.cells.count == 1)
        #expect(analysis.cells[0].position == 2)
        #expect(analysis.cells[0].isBalancing)
        #expect(analysis.balancingCellCount == 1)
        #expect(analysis.batteryTemperatures?.averageCelsius == 25)
    }

    @Test("Never reports healthy before cells are available")
    func requiresCellsForHealthyStatus() {
        let analysis = analyzer.analyze(health(stateOfHealth: 95))

        #expect(analysis.severity == .unknown)
    }

    @Test("BMS fault always wins")
    func prioritizesBMSFault() {
        let analysis = analyzer.analyze(health(isFaultActive: true))

        #expect(analysis.severity == .critical)
        #expect(analysis.isBMSFaultActive)
    }

    private func health(
        stateOfHealth: Int? = 95,
        cells: [BatteryCellVoltage] = [],
        balancingIndexes: Set<Int> = [],
        temperatures: [BatteryTemperature] = [],
        isFaultActive: Bool = false
    ) -> BikeBatteryHealth {
        .init(
            stateOfHealth: stateOfHealth.map(HealthLevel.known) ?? .unknown,
            isFaultActive: isFaultActive,
            cellVoltages: cells,
            balancingCellIndexes: balancingIndexes,
            temperatures: temperatures
        )
    }
}
