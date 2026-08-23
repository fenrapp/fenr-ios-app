@testable import BikeSDK
import CoreBluetooth
import StarkProtocol
import Testing

@MainActor
@Suite("BLE session store")
struct BLESessionStoreTests {
    @Test("Notification subscription queue is ordered and deduplicated")
    func notificationQueueIsOrderedAndDeduplicated() throws {
        let store = BLESessionStore()
        let status = makeMutableCharacteristic(uuid: StarkUUIDs.bikeStatus)
        let speed = makeMutableCharacteristic(uuid: StarkUUIDs.liveSpeed)

        store.enqueueNotificationCharacteristic(status)
        store.enqueueNotificationCharacteristic(status)
        store.enqueueNotificationCharacteristic(speed)

        #expect(try #require(store.startNextNotificationCharacteristic()).uuid == status.uuid)
        #expect(store.completeActiveNotificationCharacteristic(matching: status.uuid))
        #expect(try #require(store.startNextNotificationCharacteristic()).uuid == speed.uuid)
        #expect(store.completeActiveNotificationCharacteristic(matching: speed.uuid))
        #expect(store.startNextNotificationCharacteristic() == nil)
    }

    @Test("Unsubscription queue is serial and does not affect the base subscription queue")
    func unsubscriptionQueueIsSerial() throws {
        let store = BLESessionStore()
        let batteryHealth = makeMutableCharacteristic(uuid: StarkUUIDs.batteryCellVoltages)
        let baseTelemetry = makeMutableCharacteristic(uuid: StarkUUIDs.batterySOC)

        store.setSubscribed(batteryHealth.uuid)
        store.enqueueNotificationCharacteristic(baseTelemetry)
        store.enqueueUnsubscriptionCharacteristic(batteryHealth)

        #expect(try #require(store.startNextUnsubscriptionCharacteristic()).uuid == batteryHealth.uuid)
        #expect(store.startNextNotificationCharacteristic() == nil)
        #expect(store.completeActiveUnsubscriptionCharacteristic(matching: batteryHealth.uuid))
        store.removeSubscribed(batteryHealth.uuid)
        #expect(try #require(store.startNextNotificationCharacteristic()).uuid == baseTelemetry.uuid)
    }

    @Test("Session reset preserves reconnect intent and clears only transient state")
    func resetPreservesReconnectIntent() {
        let store = BLESessionStore()
        let characteristic = makeMutableCharacteristic(uuid: StarkUUIDs.batterySOC)
        store.setTargetVIN("VIN123")
        store.setReconnectIntent(true)
        store.setCharacteristic(characteristic)
        store.enqueueNotificationCharacteristic(characteristic)
        store.setAuthenticationState(.authenticated)
        store.setSubscribed(characteristic.uuid)

        store.resetSession()

        #expect(store.targetVIN == "VIN123")
        #expect(store.shouldConnectWhenPoweredOn)
        #expect(store.discoveredCharacteristics.isEmpty)
        #expect(store.pendingNotificationCharacteristics.isEmpty)
        #expect(store.subscribedCharacteristics.isEmpty)
        #expect(store.authenticationState == .idle)
    }
}
