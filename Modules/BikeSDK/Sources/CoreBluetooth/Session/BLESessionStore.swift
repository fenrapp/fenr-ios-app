import CoreBluetooth
import StarkProtocol

@MainActor
public final class BLESessionStore {
    enum TelemetryRetryOperation: Hashable {
        case descriptors, subscription, read
    }

    public private(set) var generation = 0
    public private(set) var hasReportedDashboardTelemetry = false
    private var telemetryRetries: [CBUUID: Set<TelemetryRetryOperation>] = [:]
    public private(set) var targetVIN = ""
    public private(set) var peripheral: CBPeripheral?
    public private(set) var discoveredCharacteristics: [CBUUID: CBCharacteristic] = [:]
    public private(set) var subscribedCharacteristics = Set<CBUUID>()
    public private(set) var pendingNotificationCharacteristics: [CBCharacteristic] = []
    public private(set) var activeNotificationCharacteristic: CBCharacteristic?
    public private(set) var pendingUnsubscriptionCharacteristics: [CBCharacteristic] = []
    public private(set) var activeUnsubscriptionCharacteristic: CBCharacteristic?
    public private(set) var authenticationState = BLEAuthenticationState.idle
    public private(set) var shouldConnectWhenPoweredOn = false
    public private(set) var receivedTelemetryCharacteristics = Set<CBUUID>()
    public private(set) var hasReportedCompleteTelemetry = false
    public private(set) var hasReportedRequiredSubscriptions = false
    public private(set) var hasStartedExperimentalCapture = false
    public private(set) var pendingExperimentalCharacteristics: [CBCharacteristic] = []
    public private(set) var activeExperimentalCaptureCharacteristic: CBCharacteristic?
    private var batteryHealthMonitoringLeaseCount = 0
    private var imuMonitoringLeaseCount = 0

    public init() {}

    func authenticatedConnectionName(fallback: String?) -> String? {
        guard authenticationState == .authenticated,
              StarkPairingIdentity.isValidVIN(targetVIN) else { return fallback }
        return StarkPairingIdentity.normalizedVIN(targetVIN)
    }

    public func setTargetVIN(_ vin: String) {
        targetVIN = vin
    }

    public func setReconnectIntent(_ shouldReconnect: Bool) {
        shouldConnectWhenPoweredOn = shouldReconnect
    }

    public func setPeripheral(_ peripheral: CBPeripheral) {
        self.peripheral = peripheral
    }

    public func isActive(_ peripheral: CBPeripheral) -> Bool {
        self.peripheral?.identifier == peripheral.identifier
    }

    public func setCharacteristic(_ characteristic: CBCharacteristic) {
        discoveredCharacteristics[characteristic.uuid] = characteristic
    }

    public func enqueueNotificationCharacteristic(_ characteristic: CBCharacteristic) {
        guard !pendingNotificationCharacteristics.contains(where: { $0.uuid == characteristic.uuid }) else { return }
        guard activeNotificationCharacteristic?.uuid != characteristic.uuid else { return }
        guard !subscribedCharacteristics.contains(characteristic.uuid) else { return }
        pendingNotificationCharacteristics.append(characteristic)
    }

    public func removePendingNotificationCharacteristic(uuid: CBUUID) {
        pendingNotificationCharacteristics.removeAll { $0.uuid == uuid }
    }

    public func startNextNotificationCharacteristic() -> CBCharacteristic? {
        guard !hasActiveNotificationOperation else { return nil }
        guard !pendingNotificationCharacteristics.isEmpty else { return nil }
        let index = pendingNotificationCharacteristics.firstIndex {
            BikeSDKConstants.dashboardTelemetryUUIDs.contains($0.uuid)
        } ?? pendingNotificationCharacteristics.startIndex
        activeNotificationCharacteristic = pendingNotificationCharacteristics.remove(at: index)
        return activeNotificationCharacteristic
    }

    public func completeActiveNotificationCharacteristic(matching uuid: CBUUID) -> Bool {
        guard activeNotificationCharacteristic?.uuid == uuid else { return false }
        activeNotificationCharacteristic = nil
        return true
    }

    public func enqueueUnsubscriptionCharacteristic(_ characteristic: CBCharacteristic) {
        guard subscribedCharacteristics.contains(characteristic.uuid) else { return }
        guard !pendingUnsubscriptionCharacteristics.contains(where: { $0.uuid == characteristic.uuid }) else { return }
        guard activeUnsubscriptionCharacteristic?.uuid != characteristic.uuid else { return }
        pendingUnsubscriptionCharacteristics.append(characteristic)
    }

    public func startNextUnsubscriptionCharacteristic() -> CBCharacteristic? {
        guard !hasActiveNotificationOperation else { return nil }
        guard !pendingUnsubscriptionCharacteristics.isEmpty else { return nil }
        activeUnsubscriptionCharacteristic = pendingUnsubscriptionCharacteristics.removeFirst()
        return activeUnsubscriptionCharacteristic
    }

    public func completeActiveUnsubscriptionCharacteristic(matching uuid: CBUUID) -> Bool {
        guard activeUnsubscriptionCharacteristic?.uuid == uuid else { return false }
        activeUnsubscriptionCharacteristic = nil
        return true
    }

    public func setSubscribed(_ uuid: CBUUID) {
        subscribedCharacteristics.insert(uuid)
    }

    public func removeSubscribed(_ uuid: CBUUID) {
        subscribedCharacteristics.remove(uuid)
    }

    public func acquireBatteryHealthMonitoringLease() -> Bool {
        batteryHealthMonitoringLeaseCount += 1
        return batteryHealthMonitoringLeaseCount == 1
    }

    public func releaseBatteryHealthMonitoringLease() -> Bool {
        guard batteryHealthMonitoringLeaseCount > 0 else { return false }
        batteryHealthMonitoringLeaseCount -= 1
        return batteryHealthMonitoringLeaseCount == 0
    }

    public func isBatteryHealthMonitoringActive() -> Bool {
        batteryHealthMonitoringLeaseCount > 0
    }

    public func acquireIMUMonitoringLease() -> Bool {
        imuMonitoringLeaseCount += 1
        return imuMonitoringLeaseCount == 1
    }

    public func releaseIMUMonitoringLease() -> Bool {
        guard imuMonitoringLeaseCount > 0 else { return false }
        imuMonitoringLeaseCount -= 1
        return imuMonitoringLeaseCount == 0
    }

    public func isIMUMonitoringActive() -> Bool {
        imuMonitoringLeaseCount > 0
    }

    public var hasActiveNotificationOperation: Bool {
        activeNotificationCharacteristic != nil || activeUnsubscriptionCharacteristic != nil
    }

    public func markRequiredSubscriptionsCompleted(requiredUUIDs: [CBUUID]) -> Bool {
        guard !hasReportedRequiredSubscriptions else { return false }
        guard Set(requiredUUIDs).isSubset(of: subscribedCharacteristics) else { return false }
        hasReportedRequiredSubscriptions = true
        return true
    }

    var shouldPublishSubscribedConnectionState: Bool {
        !hasReportedDashboardTelemetry && !hasReportedCompleteTelemetry
    }

    public func markExperimentalCaptureStarted() -> Bool {
        guard !hasStartedExperimentalCapture else { return false }
        hasStartedExperimentalCapture = true
        return true
    }

    public func enqueueExperimentalCaptureCharacteristic(_ characteristic: CBCharacteristic) {
        guard !pendingExperimentalCharacteristics.contains(where: { $0.uuid == characteristic.uuid }) else {
            return
        }
        guard activeExperimentalCaptureCharacteristic?.uuid != characteristic.uuid else { return }
        pendingExperimentalCharacteristics.append(characteristic)
    }

    public func startNextExperimentalCaptureCharacteristic() -> CBCharacteristic? {
        guard activeExperimentalCaptureCharacteristic == nil else { return nil }
        guard !pendingExperimentalCharacteristics.isEmpty else { return nil }
        activeExperimentalCaptureCharacteristic = pendingExperimentalCharacteristics.removeFirst()
        return activeExperimentalCaptureCharacteristic
    }

    public func completeActiveExperimentalCaptureCharacteristic(matching uuid: CBUUID) -> Bool {
        guard activeExperimentalCaptureCharacteristic?.uuid == uuid else { return false }
        activeExperimentalCaptureCharacteristic = nil
        return true
    }

    public func setAuthenticationState(_ state: BLEAuthenticationState) {
        authenticationState = state
    }

    public func markTelemetryReceived(
        characteristicUUID: CBUUID,
        requiredCharacteristicUUIDs: [CBUUID]
    ) -> Bool {
        receivedTelemetryCharacteristics.insert(characteristicUUID)
        guard !hasReportedCompleteTelemetry else { return false }
        guard Set(requiredCharacteristicUUIDs).isSubset(of: receivedTelemetryCharacteristics) else {
            return false
        }
        hasReportedCompleteTelemetry = true
        return true
    }

    func markDashboardTelemetryReady() -> Bool {
        guard authenticationState == .authenticated, !hasReportedDashboardTelemetry,
              !receivedTelemetryCharacteristics.isDisjoint(with: BikeSDKConstants.dashboardTelemetryUUIDs)
        else { return false }
        hasReportedDashboardTelemetry = true
        return true
    }

    func claimTelemetryRetry(for uuid: CBUUID, operation: TelemetryRetryOperation) -> Bool {
        guard BikeSDKConstants.telemetryCharacteristicUUIDs.contains(uuid) else { return false }
        return telemetryRetries[uuid, default: []].insert(operation).inserted
    }

    public func resetSession() {
        generation += 1
        hasReportedDashboardTelemetry = false
        telemetryRetries.removeAll()
        peripheral?.delegate = nil
        peripheral = nil
        discoveredCharacteristics.removeAll()
        subscribedCharacteristics.removeAll()
        pendingNotificationCharacteristics.removeAll()
        activeNotificationCharacteristic = nil
        pendingUnsubscriptionCharacteristics.removeAll()
        activeUnsubscriptionCharacteristic = nil
        authenticationState = .idle
        receivedTelemetryCharacteristics.removeAll()
        hasReportedCompleteTelemetry = false
        hasReportedRequiredSubscriptions = false
        hasStartedExperimentalCapture = false
        pendingExperimentalCharacteristics.removeAll()
        activeExperimentalCaptureCharacteristic = nil
        batteryHealthMonitoringLeaseCount = 0
        imuMonitoringLeaseCount = 0
    }
}
