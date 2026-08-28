@testable import BikeSDK
import Foundation
import StarkProtocol
import Testing

@MainActor
@Suite("Bike BLE charge power coordinator")
struct BikeBLEChargePowerCoordinatorTests {
    @Test("Setting 3300 watts repairs a stale two ampere current limit")
    func settingMaximumPowerRepairsTwoAmpereLimit() async throws {
        let transport = FakeBikeBLEChargePowerConfigurationTransport()
        let coordinator = BikeBLEChargePowerCoordinator(
            transport: transport,
            verificationWaiter: ImmediateBikeBLEChargePowerVerificationWaiter()
        )

        _ = try await coordinator.prepareChargePowerControl(context: telemetryContext)
        let snapshot = try await coordinator.setChargePowerLimit(watts: 3_300)

        let write = try #require(transport.writePayloads.last)
        #expect(write[3] == 0xC8)
        #expect(write[4] == 0x00)
        #expect(write[5] == 0xE4)
        #expect(write[6] == 0x0C)
        #expect(snapshot.parsedConfig.chargeCurrentDeciAmperes == 200)
        #expect(snapshot.parsedConfig.chargePowerWatts == 3_300)
        #expect(transport.requests == Array(
            repeating: StarkChargerConfigurationCommand.readPacket,
            count: 3
        ))
    }

    @Test("Setting 7000 watts repairs current and preserves fast charger capacity")
    func settingFastChargePowerRepairsCurrent() async throws {
        let transport = FakeBikeBLEChargePowerConfigurationTransport()
        transport.response = Data([
            0x02, 0x04, 0x00,
            0x14, 0x00,
            0xE4, 0x0C,
            0xE8, 0x03,
            0x14, 0x00,
            0x02, 0x00,
            0x10, 0x00,
            0xE4, 0x0C,
            0x58, 0x1B
        ])
        let coordinator = BikeBLEChargePowerCoordinator(
            transport: transport,
            verificationWaiter: ImmediateBikeBLEChargePowerVerificationWaiter()
        )

        _ = try await coordinator.prepareChargePowerControl(context: fastTelemetryContext)
        let snapshot = try await coordinator.setChargePowerLimit(watts: 7_000)

        let write = try #require(transport.writePayloads.last)
        #expect(write[3] == 0xFA)
        #expect(write[4] == 0x00)
        #expect(write[5] == 0x58)
        #expect(write[6] == 0x1B)
        #expect(write[9] == 0xE4)
        #expect(write[10] == 0x0C)
        #expect(write[11] == 0x58)
        #expect(write[12] == 0x1B)
        #expect(snapshot.parsedConfig.chargeCurrentDeciAmperes == 250)
        #expect(snapshot.parsedConfig.chargePowerWatts == 7_000)
        #expect(snapshot.parsedConfig.backpackChargerMaximumPowerWatts == 7_000)
    }

    @Test("A charger write is rejected when the fresh response does not confirm it")
    func rejectsUnconfirmedWrite() async throws {
        let transport = FakeBikeBLEChargePowerConfigurationTransport()
        let coordinator = BikeBLEChargePowerCoordinator(
            transport: transport,
            verificationWaiter: ImmediateBikeBLEChargePowerVerificationWaiter()
        )
        _ = try await coordinator.prepareChargePowerControl(context: telemetryContext)
        transport.ignoresWrites = true

        await #expect(throws: BikeSDKError.self) {
            _ = try await coordinator.setChargePowerLimit(watts: 3_300)
        }
    }

    private var telemetryContext: BikeSDKChargePowerTelemetryContext {
        BikeSDKChargePowerTelemetryContext(
            requestedCurrentAmperes: 2,
            maximumCurrentAmperes: 2,
            maximumPowerWatts: 3_300,
            maximumStateOfChargePercent: 100,
            chargerTypeRaw: 3
        )
    }

    private var fastTelemetryContext: BikeSDKChargePowerTelemetryContext {
        BikeSDKChargePowerTelemetryContext(
            requestedCurrentAmperes: 2,
            maximumCurrentAmperes: 2,
            maximumPowerWatts: 7_000,
            maximumStateOfChargePercent: 100,
            chargerTypeRaw: 2
        )
    }
}
