@testable import BikeSDK
import CoreBluetooth
import Foundation
import StarkProtocol
import Testing

@Suite("Bike SDK profile and session")
struct BikeSDKProfileAndSessionTests {
    @Test("BLE diagnostics is scoped to the observed firmware profile")
    func diagnosticsFirmwareProfile() {
        #expect(BikeBLEDiagnosticsProfile.firmware == .currentObserved)
    }

    @Test("BLE v1 does not discover encrypted VIN characteristic")
    func excludesVINCharacteristicFromDiscoveryPolicy() {
        let vinUUID = CBUUID(nsuuid: StarkUUIDs.vin)

        #expect(!BikeSDKConstants.characteristicUUIDs.contains(vinUUID))
        #expect(!BikeSDKConstants.requiredTelemetryNotifyUUIDs.contains(vinUUID))
    }

    @Test("BLE diagnostics discovers the experimental capture surface without making it required")
    func discoversBikeDiagnosticsTelemetrySurface() {
        #expect(BikeSDKConstants.serviceUUIDs == expectedServiceUUIDs)
        #expect(BikeSDKConstants.characteristicUUIDs.contains(CBUUID(nsuuid: StarkUUIDs.batteryCellVoltages)))
        #expect(BikeSDKConstants.characteristicUUIDs.contains(CBUUID(nsuuid: StarkUUIDs.chargerData)))
        #expect(BikeSDKConstants.requiredTelemetryNotifyUUIDs == expectedRequiredTelemetryUUIDs)
        #expect(!BikeSDKConstants.requiredTelemetryNotifyUUIDs.contains(
            CBUUID(nsuuid: StarkUUIDs.batteryCellVoltages)
        ))
        #expect(!BikeSDKConstants.experimentalCaptureUUIDs.contains(
            CBUUID(nsuuid: StarkUUIDs.liveIMU)
        ))
        #expect(BikeSDKConstants.imuMonitoringUUID == CBUUID(nsuuid: StarkUUIDs.liveIMU))
        #expect(!BikeSDKConstants.requiredTelemetryNotifyUUIDs.contains(BikeSDKConstants.imuMonitoringUUID))
        #expect(!BikeSDKConstants.experimentalCaptureUUIDs.contains(
            CBUUID(nsuuid: StarkUUIDs.liveTotals)
        ))
        #expect(!BikeSDKConstants.experimentalCaptureUUIDs.contains(
            CBUUID(nsuuid: StarkUUIDs.vcuTelemetryTLV)
        ))
        #expect(!BikeSDKConstants.experimentalCaptureUUIDs.contains(
            CBUUID(nsuuid: StarkUUIDs.liveEstimation)
        ))
        #expect(!BikeSDKConstants.experimentalCaptureUUIDs.contains(
            CBUUID(nsuuid: StarkUUIDs.liveRacing)
        ))
        #expect(BikeSDKConstants.characteristicUUIDs.contains(
            CBUUID(nsuuid: StarkUUIDs.liveEstimation)
        ))
        #expect(!BikeSDKConstants.characteristicUUIDs.contains(
            CBUUID(nsuuid: StarkUUIDs.liveRacing)
        ))
        #expect(!BikeSDKConstants.characteristicUUIDs.contains(
            CBUUID(nsuuid: StarkUUIDs.vcuInfo)
        ))
        #expect(BikeSDKConstants.experimentalCaptureUUIDs == expectedExperimentalCaptureUUIDs)
        #expect(BikeSDKConstants.characteristicUUIDs.contains(
            CBUUID(nsuuid: StarkUUIDs.vcuBikeConfiguration)
        ))
        #expect(!BikeSDKConstants.requiredTelemetryNotifyUUIDs.contains(
            CBUUID(nsuuid: StarkUUIDs.vcuBikeConfiguration)
        ))
        #expect(!BikeSDKConstants.experimentalCaptureUUIDs.contains(
            CBUUID(nsuuid: StarkUUIDs.vcuBikeConfiguration)
        ))
        #expect(!BikeSDKConstants.characteristicUUIDs.contains(
            CBUUID(nsuuid: StarkUUIDs.inverterTelemetryTLVConfiguration)
        ))
        #expect(BikeSDKConstants.requiredCharacteristicUUIDs(
            for: CBUUID(nsuuid: StarkUUIDs.vcuService)
        ).isEmpty)
        #expect(BikeSDKConstants.requiredCharacteristicUUIDs(
            for: CBUUID(nsuuid: StarkUUIDs.batteryService)
        ).isEmpty)
    }

    @Test("New electrical characteristics are readable and optional")
    func electricalCharacteristicsAreOptional() {
        let optionalUUIDs = [
            CBUUID(nsuuid: StarkUUIDs.liveEstimation),
            CBUUID(nsuuid: StarkUUIDs.batteryParams),
            CBUUID(nsuuid: StarkUUIDs.batterySignals)
        ]

        #expect(BikeSDKConstants.telemetrySnapshotUUIDs == [
            CBUUID(nsuuid: StarkUUIDs.batterySOC)
        ] + optionalUUIDs)
        #expect(optionalUUIDs.allSatisfy(BikeSDKConstants.characteristicUUIDs.contains))
        #expect(optionalUUIDs.allSatisfy { !BikeSDKConstants.requiredTelemetryNotifyUUIDs.contains($0) })
    }

    private var expectedServiceUUIDs: [CBUUID] {
        [
            CBUUID(nsuuid: StarkUUIDs.bikeService),
            CBUUID(nsuuid: StarkUUIDs.liveService),
            CBUUID(nsuuid: StarkUUIDs.batteryService),
            CBUUID(nsuuid: StarkUUIDs.chargerService),
            CBUUID(nsuuid: StarkUUIDs.vcuService),
            CBUUID(nsuuid: StarkUUIDs.inverterService)
        ]
    }

    private var expectedRequiredTelemetryUUIDs: [CBUUID] {
        [
            CBUUID(nsuuid: StarkUUIDs.bikeStatus),
            CBUUID(nsuuid: StarkUUIDs.liveSpeed),
            CBUUID(nsuuid: StarkUUIDs.liveMap),
            CBUUID(nsuuid: StarkUUIDs.liveTotals),
            CBUUID(nsuuid: StarkUUIDs.batterySOC),
            CBUUID(nsuuid: StarkUUIDs.vcuTelemetryTLV)
        ]
    }

    @Test("Battery Health profile contains only read-only monitoring datasets")
    func batteryHealthMonitoringProfile() {
        #expect(BikeSDKConstants.batteryHealthMonitoringUUIDs == [
            CBUUID(nsuuid: StarkUUIDs.batteryStatus),
            CBUUID(nsuuid: StarkUUIDs.batteryTemperatures),
            CBUUID(nsuuid: StarkUUIDs.batteryDCBus),
            CBUUID(nsuuid: StarkUUIDs.batteryCellVoltages),
            CBUUID(nsuuid: StarkUUIDs.batteryBalancing),
            CBUUID(nsuuid: StarkUUIDs.batterySignals),
            CBUUID(nsuuid: StarkUUIDs.chargerData),
            CBUUID(nsuuid: StarkUUIDs.inverterTemperatures)
        ])
    }

    private var expectedExperimentalCaptureUUIDs: [CBUUID] {
        [
            CBUUID(nsuuid: StarkUUIDs.bikeTelemetryTLV),
            CBUUID(nsuuid: StarkUUIDs.liveTelemetryTLV),
            CBUUID(nsuuid: StarkUUIDs.chargerTelemetryTLV),
            CBUUID(nsuuid: StarkUUIDs.batteryTelemetryTLV),
            CBUUID(nsuuid: StarkUUIDs.inverterInfo),
            CBUUID(nsuuid: StarkUUIDs.inverterSignals),
            CBUUID(nsuuid: StarkUUIDs.inverterPCB),
            CBUUID(nsuuid: StarkUUIDs.inverterTelemetryTLV)
        ]
    }

    @MainActor
    @Test("Session reports complete telemetry only after every diagnostics characteristic arrives")
    func completeTelemetryRequiresEveryCharacteristic() throws {
        let store = BLESessionStore()
        let requiredUUIDs = BikeSDKConstants.requiredTelemetryNotifyUUIDs
        let finalCharacteristicUUID = try #require(requiredUUIDs.last)
        let repeatedCharacteristicUUID = try #require(requiredUUIDs.first)

        for characteristicUUID in requiredUUIDs.dropLast() {
            #expect(!store.markTelemetryReceived(
                characteristicUUID: characteristicUUID,
                requiredCharacteristicUUIDs: requiredUUIDs
            ))
        }
        #expect(store.markTelemetryReceived(
            characteristicUUID: finalCharacteristicUUID,
            requiredCharacteristicUUIDs: requiredUUIDs
        ))
        #expect(!store.shouldPublishSubscribedConnectionState)
        #expect(!store.markTelemetryReceived(
            characteristicUUID: repeatedCharacteristicUUID,
            requiredCharacteristicUUIDs: requiredUUIDs
        ))

        store.resetSession()
        #expect(store.receivedTelemetryCharacteristics.isEmpty)
        #expect(!store.hasReportedCompleteTelemetry && store.shouldPublishSubscribedConnectionState)
        #expect(!store.hasReportedRequiredSubscriptions)
    }

    @MainActor
    @Test("Subscription queue ignores callbacks for a different characteristic")
    func subscriptionCallbackMustMatchActiveCharacteristic() throws {
        let active = makeMutableCharacteristic(uuid: StarkUUIDs.bikeStatus)
        let unrelated = makeMutableCharacteristic(uuid: StarkUUIDs.liveSpeed)
        let store = BLESessionStore()
        store.enqueueNotificationCharacteristic(active)

        let started = try #require(store.startNextNotificationCharacteristic())

        #expect(started.uuid == active.uuid)
        #expect(!store.completeActiveNotificationCharacteristic(matching: unrelated.uuid))
        #expect(store.activeNotificationCharacteristic?.uuid == active.uuid)
        #expect(store.completeActiveNotificationCharacteristic(matching: active.uuid))
        #expect(store.activeNotificationCharacteristic == nil)
    }

    @MainActor
    @Test("Battery Health lease is reference counted and reset with the session")
    func batteryHealthLease() {
        let store = BLESessionStore()

        #expect(store.acquireBatteryHealthMonitoringLease())
        #expect(!store.acquireBatteryHealthMonitoringLease())
        #expect(store.isBatteryHealthMonitoringActive())
        #expect(!store.releaseBatteryHealthMonitoringLease())
        #expect(store.releaseBatteryHealthMonitoringLease())
        #expect(!store.isBatteryHealthMonitoringActive())

        _ = store.acquireBatteryHealthMonitoringLease()
        store.resetSession()
        #expect(!store.isBatteryHealthMonitoringActive())
    }

    @MainActor
    @Test("Required subscriptions are reported once per session")
    func requiredSubscriptionsAreReportedOnce() throws {
        let store = BLESessionStore()
        let requiredUUIDs = BikeSDKConstants.requiredTelemetryNotifyUUIDs
        let finalUUID = try #require(requiredUUIDs.last)

        requiredUUIDs.dropLast().forEach(store.setSubscribed)
        #expect(!store.markRequiredSubscriptionsCompleted(requiredUUIDs: requiredUUIDs))

        store.setSubscribed(finalUUID)
        #expect(store.markRequiredSubscriptionsCompleted(requiredUUIDs: requiredUUIDs))
        #expect(!store.markRequiredSubscriptionsCompleted(requiredUUIDs: requiredUUIDs))

        store.resetSession()
        #expect(!store.hasReportedRequiredSubscriptions)
    }

    @MainActor
    @Test("Experimental capture starts once and resets with the session")
    func experimentalCaptureStartsOnce() {
        let store = BLESessionStore()

        #expect(store.markExperimentalCaptureStarted())
        #expect(!store.markExperimentalCaptureStarted())

        store.resetSession()

        #expect(!store.hasStartedExperimentalCapture)
        #expect(store.markExperimentalCaptureStarted())
    }

    @MainActor
    @Test("Experimental capture queue advances one characteristic at a time")
    func experimentalCaptureQueue() throws {
        let first = makeMutableCharacteristic(uuid: StarkUUIDs.liveThrottle)
        let second = makeMutableCharacteristic(uuid: StarkUUIDs.liveIMU)
        let store = BLESessionStore()

        store.enqueueExperimentalCaptureCharacteristic(first)
        store.enqueueExperimentalCaptureCharacteristic(second)

        #expect(try #require(store.startNextExperimentalCaptureCharacteristic()).uuid == first.uuid)
        #expect(store.startNextExperimentalCaptureCharacteristic() == nil)
        #expect(store.completeActiveExperimentalCaptureCharacteristic(matching: first.uuid))
        #expect(try #require(store.startNextExperimentalCaptureCharacteristic()).uuid == second.uuid)
    }

    @MainActor
    @Test("Session reset clears Stark authentication state")
    func sessionResetClearsAuthentication() {
        let store = BLESessionStore()
        store.setAuthenticationState(.authenticated)

        store.resetSession()

        #expect(store.authenticationState == .idle)
    }

    @Test("Event hub sends events to multiple consumers")
    func eventHub() async {
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let firstStream = await hub.stream()
        let secondStream = await hub.stream()
        let first = firstStream.makeAsyncIterator()
        let second = secondStream.makeAsyncIterator()
        await hub.send(.rssi(-61))
        var firstIterator = first
        var secondIterator = second
        await #expect(firstIterator.next() == .rssi(-61))
        await #expect(secondIterator.next() == .rssi(-61))
    }

    @Test("Notification debug maps metadata and bytes")
    func notificationDebug() {
        let mapper = makeNotificationMapper()
        let date = Date(timeIntervalSince1970: 0)
        let debug = mapper.debug(
            characteristic: StarkUUIDs.liveSpeed,
            data: BikeSDKPayloadFixtures.debugBytes,
            date: date
        )

        #expect(debug.characteristic == StarkUUIDs.liveSpeed)
        #expect(debug.byteCount == 2)
        #expect(debug.hex == "0A 0B")
        #expect(debug.date == date)
    }
}
