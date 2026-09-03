import BLETraceDomain
import CoreBluetooth
import Foundation
import StarkProtocol

@MainActor
final class BikeBLETraceEmitter {
    private let recorder: any BLETraceRecording
    private let now: @Sendable () -> Date
    private let uptimeNanoseconds: @Sendable () -> UInt64
    private let makeSessionID: @Sendable () -> UUID
    private var targetVIN = ""
    private var recordingState = RecordingState.inactive
    private var sessionGeneration = 0
    private var closeTask: Task<Void, Never>?
    private var closeDestination: CloseDestination?
    private var bufferedEvents: [BLETraceEvent] = []
    private var pendingReads = Set<CBUUID>()

    init(
        recorder: any BLETraceRecording,
        now: @escaping @Sendable () -> Date,
        uptimeNanoseconds: @escaping @Sendable () -> UInt64,
        makeSessionID: @escaping @Sendable () -> UUID
    ) {
        self.recorder = recorder
        self.now = now
        self.uptimeNanoseconds = uptimeNanoseconds
        self.makeSessionID = makeSessionID
    }

    func record(
        category: String,
        operation: BLETraceOperation,
        direction: BLETraceDirection,
        serviceUUID: CBUUID? = nil,
        characteristicUUID: CBUUID? = nil,
        characteristicProperties: String? = nil,
        data: Data? = nil,
        decodeStatus: BLETraceDecodeStatus? = nil,
        readPending: Bool? = nil,
        detail: String? = nil,
        error: Error? = nil
    ) async {
        guard recordingState == .active || recordingState == .starting else { return }
        let event = makeEvent(
            timestamp: now(),
            uptimeNanoseconds: uptimeNanoseconds(),
            category: category,
            operation: operation,
            direction: direction,
            serviceUUID: serviceUUID,
            characteristicUUID: characteristicUUID,
            characteristicProperties: characteristicProperties,
            data: data,
            decodeStatus: decodeStatus,
            readPending: readPending,
            detail: detail,
            error: error
        )
        guard recordingState == .active else {
            bufferedEvents.append(event)
            return
        }
        await recorder.record(event)
    }

    func recordConnectionState(_ status: BikeSDKConnectionStatus) async {
        await record(
            category: "connection_state",
            operation: .connectionStateChanged,
            direction: .internalEvent,
            detail: connectionStateDetail(status)
        )
    }

    private func makeEvent(
        timestamp: Date,
        uptimeNanoseconds: UInt64,
        category: String,
        operation: BLETraceOperation,
        direction: BLETraceDirection,
        serviceUUID: CBUUID? = nil,
        characteristicUUID: CBUUID? = nil,
        characteristicProperties: String? = nil,
        data: Data? = nil,
        decodeStatus: BLETraceDecodeStatus? = nil,
        readPending: Bool? = nil,
        detail: String? = nil,
        error: Error? = nil
    ) -> BLETraceEvent {
        let isSensitive = characteristicUUID.map(isSensitiveCharacteristic) ?? false
        let nsError = error as NSError?
        let traceError = nsError.map {
            BLETraceError(
                domain: redact($0.domain),
                code: $0.code,
                detail: redact($0.localizedDescription)
            )
        }
        return BLETraceEvent(
            timestamp: timestamp,
            uptimeNanoseconds: uptimeNanoseconds,
            category: category,
            operation: operation,
            direction: direction,
            serviceUUID: serviceUUID?.uuidString,
            characteristicUUID: characteristicUUID?.uuidString,
            characteristicProperties: characteristicProperties,
            byteCount: data?.count,
            payloadHex: isSensitive ? nil : data?.bikeSDKHexString,
            payloadRedacted: isSensitive && data != nil,
            decodeStatus: decodeStatus,
            readPending: readPending,
            detail: detail.map(redact),
            error: traceError
        )
    }

    private func connectionStateDetail(_ status: BikeSDKConnectionStatus) -> String {
        switch status {
        case .idle: "idle"
        case .bluetoothUnavailable: "bluetooth_unavailable"
        case .bluetoothUnauthorized: "bluetooth_unauthorized"
        case .bluetoothPoweredOff: "bluetooth_powered_off"
        case .scanning: "scanning"
        case .connecting: "connecting"
        case .discovering: "discovering"
        case .authenticating: "authenticating"
        case .authenticated: "authenticated"
        case .subscribed: "subscribed"
        case .receivingTelemetry: "receiving_telemetry"
        case .reconnecting(_, let attempt, let maximumAttempts):
            "reconnecting attempt=\(attempt) maximum=\(maximumAttempts)"
        case .pairingResetRequired: "pairing_reset_required"
        case .disconnected: "disconnected"
        case .failed: "failed"
        }
    }

    func recordReadRequested(characteristic: CBCharacteristic) async {
        pendingReads.insert(characteristic.uuid)
        await record(
            category: "gatt",
            operation: .readRequested,
            direction: .outbound,
            serviceUUID: characteristic.service?.uuid,
            characteristicUUID: characteristic.uuid,
            characteristicProperties: characteristic.properties.protocolDescription
        )
    }

    func recordValueUpdate(characteristic: CBCharacteristic, error: Error?) async {
        let wasReadPending = pendingReads.remove(characteristic.uuid) != nil
        await record(
            category: "gatt",
            operation: .valueUpdated,
            direction: .inbound,
            serviceUUID: characteristic.service?.uuid,
            characteristicUUID: characteristic.uuid,
            characteristicProperties: characteristic.properties.protocolDescription,
            data: characteristic.value,
            readPending: wasReadPending,
            detail: wasReadPending ? "A read was pending; CoreBluetooth does not identify callback origin" : nil,
            error: error
        )
    }

    func redactedText(_ value: String) -> String {
        redact(value)
    }

    private func isSensitiveCharacteristic(_ uuid: CBUUID) -> Bool {
        uuid == BikeSDKConstants.securityCharacteristicUUID
            || uuid == CBUUID(nsuuid: StarkUUIDs.vin)
    }

    private func redact(_ value: String) -> String {
        var redacted = value
        if !targetVIN.isEmpty {
            redacted = redacted.replacingOccurrences(
                of: targetVIN,
                with: "[REDACTED_VIN]",
                options: [.caseInsensitive, .literal]
            )
        }
        let identityCandidates = redacted.split {
            !$0.isLetter && !$0.isNumber
        }
        for candidate in identityCandidates where StarkPairingIdentity.isValidVIN(String(candidate)) {
            redacted = redacted.replacingOccurrences(
                of: candidate,
                with: "[REDACTED_VIN]",
                options: [.caseInsensitive, .literal]
            )
        }
        return redacted
    }

    private enum RecordingState {
        case inactive
        case starting
        case active
        case closing
        case paused
    }

    private enum CloseDestination {
        case inactive
        case paused
    }
}

extension BikeBLETraceEmitter {
    func startSession(vin: String, reason: BLETraceSessionStartReason) async {
        if recordingState == .closing {
            let generation = sessionGeneration
            await closeTask?.value
            completeClose(generation: generation)
        }
        guard recordingState == .inactive || recordingState == .paused else { return }
        sessionGeneration += 1
        let generation = sessionGeneration
        recordingState = .starting
        targetVIN = StarkPairingIdentity.normalizedVIN(vin)
        let context = BLETraceSessionContext(
            id: makeSessionID(),
            startedAt: now(),
            startUptimeNanoseconds: uptimeNanoseconds(),
            reason: reason
        )
        await recorder.startSession(context)
        guard recordingState == .starting, sessionGeneration == generation else { return }
        await recorder.record(makeEvent(
            timestamp: context.startedAt,
            uptimeNanoseconds: context.startUptimeNanoseconds,
            category: "session",
            operation: .sessionStarted,
            direction: .internalEvent,
            detail: reason.rawValue
        ))
        guard recordingState == .starting, sessionGeneration == generation else { return }
        while !bufferedEvents.isEmpty {
            let events = bufferedEvents
            bufferedEvents.removeAll(keepingCapacity: true)
            for event in events {
                await recorder.record(event)
            }
            guard recordingState == .starting, sessionGeneration == generation else { return }
        }
        recordingState = .active
    }

    func finishSession(reason: BLETraceSessionEndReason) async {
        switch recordingState {
        case .inactive:
            targetVIN = ""
            return
        case .paused:
            recordingState = .inactive
            targetVIN = ""
            return
        case .closing:
            closeDestination = .inactive
            targetVIN = ""
            let generation = sessionGeneration
            await closeTask?.value
            completeClose(generation: generation)
            return
        case .starting, .active:
            break
        }

        await closeSession(reason: reason, destination: .inactive)
    }

    func startNewCapture() async -> Bool {
        guard recordingState == .paused, !targetVIN.isEmpty else { return false }
        let vin = targetVIN
        await startSession(vin: vin, reason: .manualRequest)
        return recordingState == .active
    }

    func stopCapture() async -> Bool {
        guard recordingState == .active || recordingState == .starting else { return false }
        await closeSession(reason: .userStopped, destination: .paused)
        return recordingState == .paused
    }

    private func closeSession(
        reason: BLETraceSessionEndReason,
        destination: CloseDestination
    ) async {
        sessionGeneration += 1
        let generation = sessionGeneration
        recordingState = .closing
        closeDestination = destination
        if destination == .inactive {
            targetVIN = ""
        }
        bufferedEvents.removeAll(keepingCapacity: true)
        pendingReads.removeAll()
        let recorder = recorder
        let task = Task {
            await recorder.finishSession(reason: reason)
        }
        closeTask = task
        await task.value
        completeClose(generation: generation)
    }

    private func completeClose(generation: Int) {
        guard recordingState == .closing, sessionGeneration == generation else { return }
        let destination = closeDestination ?? .inactive
        recordingState = destination == .paused ? .paused : .inactive
        if destination == .inactive {
            targetVIN = ""
        }
        closeDestination = nil
        closeTask = nil
    }
}
