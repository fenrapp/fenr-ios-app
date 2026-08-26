@testable import BikeData
import BikeDomain
import BikeSDK
import Foundation
import Testing

@Suite("Bike data power and battery telemetry")
struct BikePowerBatteryRepositoryTests {
    @Test("Repository exposes confirmed power and battery telemetry")
    func mapsPowerAndBatteryTelemetry() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        let stream = await repository.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        await client.send(.telemetry(BikeDataTelemetryFixtures.batteryForPower))
        _ = await iterator.next()
        await client.send(.telemetry(BikeDataTelemetryFixtures.batterySignals))
        let telemetry = try #require(await iterator.next())

        #expect(telemetry.batteryTelemetry.dcBusRaw == 4_000)
        #expect(telemetry.batteryTelemetry.dcBusVolts == 400)
        #expect(telemetry.batteryTelemetry.currentRaw == 25)
        #expect(telemetry.batteryTelemetry.currentAmperes == 25)
        #expect(telemetry.batteryTelemetry.positiveBMS?.temperatureCelsius == 25.34)
        #expect(telemetry.batteryTelemetry.negativeBMS?.humidityPercent == 48.99)
        #expect(telemetry.powerTelemetry.electricalPowerWatts == 10_000)
        #expect(telemetry.powerTelemetry.starkMotorPowerHorsepower == 11)
    }

    @Test("Unconfirmed raw payloads do not enter domain telemetry")
    func keepsUnconfirmedPayloadsInData() async {
        let mapper = BikeSDKTelemetryPayloadToDomainMapper(powerCalculator: .init())
        let stateStore = BikeRepositoryStateStore()

        let parameters = await stateStore.updateTelemetryIf {
            mapper.apply(BikeDataTelemetryFixtures.batteryParameters, to: &$0, date: .now)
        }
        let estimations = await stateStore.updateTelemetryIf {
            mapper.apply(BikeDataTelemetryFixtures.liveEstimations, to: &$0, date: .now)
        }

        #expect(parameters == nil)
        #expect(estimations == nil)
        #expect(await stateStore.currentTelemetry() == BikeTelemetry())
    }

    @Test("Calculated power preserves negative current and reverse arrival order")
    func mapsNegativePower() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        let stream = await repository.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        await client.send(.telemetry(BikeDataTelemetryFixtures.negativeBatterySignals))
        _ = await iterator.next()
        await client.send(.telemetry(BikeDataTelemetryFixtures.batteryForPower))
        let telemetry = try #require(await iterator.next())

        #expect(telemetry.powerTelemetry.electricalPowerWatts == -10_000)
        #expect(telemetry.powerTelemetry.starkMotorPowerHorsepower == -11)
    }

    @Test("Ending the BLE session clears all power and battery telemetry")
    func resetsPowerAndBatteryTelemetry() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        let stream = await repository.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        await client.send(.telemetry(BikeDataTelemetryFixtures.batteryForPower))
        _ = await iterator.next()
        await client.send(.telemetry(BikeDataTelemetryFixtures.batterySignals))
        let populated = try #require(await iterator.next())
        #expect(populated.powerTelemetry.electricalPowerWatts == 10_000)

        await client.send(.connection(.disconnected(reason: nil)))
        let reset = try #require(await iterator.next())

        #expect(reset.powerTelemetry == BikePowerTelemetry())
        #expect(reset.batteryTelemetry == BikeBatteryTelemetry())
    }

    @Test("Notification logs retain raw bytes and decoded details")
    func mapsDecodedNotificationLog() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        let stream = await repository.observeDebugEvents()
        var iterator = stream.makeAsyncIterator()
        let characteristic = UUID(uuidString: "00006009-5374-6172-4B20-467574757265")!

        await client.send(.notification(.init(
            characteristic: characteristic,
            byteCount: 2,
            hex: "19 00",
            decodedDetail: "currentRaw=25 currentA=25.0 formula=electricalPowerW*0.0011",
            date: Date(timeIntervalSince1970: 0)
        )))
        let event = try #require(await iterator.next())

        #expect(event.detail.contains(characteristic.uuidString))
        #expect(event.detail.contains("19 00"))
        #expect(event.detail.contains("currentRaw=25"))
        #expect(event.detail.contains("formula="))
    }

}
