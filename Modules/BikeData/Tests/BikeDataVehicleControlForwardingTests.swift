@testable import BikeData
import BikeDomain
import Testing

@Suite("Bike data vehicle control forwarding")
struct BikeDataVehicleControlForwardingTests {
    @Test("Diagnostics capture controls forward without changing the bike session")
    func forwardsDiagnosticsCaptureControl() async {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)

        #expect(await repository.stopDiagnosticsCapture())
        #expect(await repository.startNewDiagnosticsCapture(vin: "FENRTEST000000001"))

        #expect(await client.invocations() == [
            .stopDiagnosticsCapture,
            .startNewDiagnosticsCapture("FENRTEST000000001")
        ])
    }

    @Test("Bike Lock preparation and writes preserve the requested state")
    func forwardsBikeLockControl() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)

        let prepared = try await repository.prepareBikeLockControl()
        let written = try await repository.setBikeLocked(true)

        #expect(prepared.isLocked == false)
        #expect(prepared.didPassNoOpWrite)
        #expect(written.isLocked)
        #expect(await client.invocations() == [
            .prepareBikeLock,
            .setBikeLocked(true)
        ])
    }

    @Test("Power mode operations forward exact indices horsepower and regeneration")
    func forwardsPowerModeControlExactly() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)

        try await repository.refreshPowerModeConfigurations()
        try await repository.refreshPowerModeConfiguration(mapIndex: 6)
        try await repository.preparePowerModeControl(mapIndex: -1)
        try await repository.setPowerModeConfiguration(
            mapIndex: 6,
            horsepower: -4,
            regenerativeBrakingPercent: 137
        )

        #expect(await client.invocations() == [
            .refreshPowerModeConfigurations,
            .refreshPowerModeConfiguration(6),
            .preparePowerModeControl(-1),
            .setPowerModeConfiguration(
                mapIndex: 6,
                horsepower: -4,
                regenerativeBrakingPercent: 137
            )
        ])
    }

    @Test("Traction operations preserve map and signed percentages")
    func forwardsTractionControlExactly() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)

        try await repository.prepareTractionControl(mapIndex: -2)
        try await repository.setTractionControlConfiguration(
            mapIndex: 7,
            powerTractionPercent: -12.5,
            brakingTractionPercent: 18.75
        )
        try await repository.refreshTractionControlConfiguration(mapIndex: 9)

        #expect(await client.invocations() == [
            .prepareTractionControl(-2),
            .setTractionControlConfiguration(
                mapIndex: 7,
                powerTractionPercent: -12.5,
                brakingTractionPercent: 18.75
            ),
            .refreshTractionControlConfiguration(9)
        ])
    }

    @Test("Charge operations preserve context power and target values")
    func forwardsChargeControlExactly() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        let status = BikeChargingStatus(
            requestedCurrentAmperes: -1.25,
            reportedCurrentAmperes: 0,
            maximumCurrentAmperes: 12.75,
            maximumPowerWatts: 7_001,
            targetCellVoltageVolts: 4.275,
            maximumStateOfChargePercent: 101,
            chargerType: .backpack
        )

        _ = try await repository.prepareChargePowerControl(chargingStatus: status)
        _ = try await repository.setChargePowerLimit(watts: -250)
        _ = try await repository.setChargeTarget(percent: 137)

        #expect(await client.invocations() == [
            .prepareChargePower(.init(
                requestedCurrentAmperes: -1.25,
                maximumCurrentAmperes: 12.75,
                maximumPowerWatts: 7_001,
                maximumStateOfChargePercent: 101,
                chargerTypeRaw: 3
            )),
            .setChargePowerLimit(-250),
            .setChargeTarget(137)
        ])
    }
}
