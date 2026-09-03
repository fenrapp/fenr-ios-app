import Foundation
import StarkProtocol

@MainActor
final class BikeBLEBikeLockConfigurationCoordinator {
    private let transport: any BikeBLEBikeLockConfigurationTransporting
    private let eventEmitter: BikeBLEEventEmitter
    private var preparedConfiguration: StarkBikeLockConfigurationPayload?
    private var preparedFirmware: StarkFirmwareVersion?

    init(
        transport: any BikeBLEBikeLockConfigurationTransporting,
        eventEmitter: BikeBLEEventEmitter
    ) {
        self.transport = transport
        self.eventEmitter = eventEmitter
    }

    func prepare() async throws -> BikeSDKBikeLockControlSnapshot {
        try transport.ensureReady()
        preparedConfiguration = nil
        preparedFirmware = nil
        let versionData = try await transport.readVersions()
        guard let firmware = StarkFirmwareVersionParser.parseVCUPic(from: versionData),
              firmware.isBikeLockControlCompatible
        else {
            throw BikeSDKError.operationFailed(
                "Bike Lock requires VCU PIC firmware 1.6.29 or newer"
            )
        }
        let configuration = try await readConfiguration()
        let noOpPacket = StarkBikeLockConfigurationCommand.noOpWritePacket(
            configuration: configuration
        )
        try await transport.writeConfiguration(noOpPacket)
        try await Task.sleep(for: Constants.writeVerificationDelay)
        let verified = try await readConfiguration()
        guard verified == configuration else {
            throw BikeSDKError.operationFailed(
                "Bike Lock no-op verification returned a different configuration"
            )
        }
        preparedConfiguration = verified
        preparedFirmware = firmware
        await report("Bike Lock prepared firmware=\(firmware.description) state=\(verified.isLocked)")
        return snapshot(configuration: verified, firmware: firmware)
    }

    func setLocked(_ isLocked: Bool) async throws -> BikeSDKBikeLockControlSnapshot {
        guard let currentConfiguration = preparedConfiguration, let preparedFirmware else {
            throw BikeSDKError.operationFailed(
                "Bike Lock has not passed its no-op preparation guard"
            )
        }
        do {
            let expected = StarkBikeLockConfigurationPayload(
                isLocked: isLocked,
                lockType: currentConfiguration.lockType,
                timeoutSeconds: currentConfiguration.timeoutSeconds
            )
            let packet = StarkBikeLockConfigurationCommand.writePacket(
                isLocked: expected.isLocked,
                lockType: expected.lockType,
                timeoutSeconds: expected.timeoutSeconds
            )
            try await transport.writeConfiguration(packet)
            try await Task.sleep(for: Constants.writeVerificationDelay)
            let verified = try await readConfiguration()
            guard verified == expected else {
                throw BikeSDKError.operationFailed(
                    "Bike Lock write was not confirmed by a fresh VCU read"
                )
            }
            preparedConfiguration = verified
            await report("Bike Lock write verified state=\(verified.isLocked)")
            return snapshot(configuration: verified, firmware: preparedFirmware)
        } catch {
            clearGuardState()
            throw error
        }
    }

    func reset() {
        clearGuardState()
    }

    private func clearGuardState() {
        preparedConfiguration = nil
        preparedFirmware = nil
    }

    private func readConfiguration() async throws -> StarkBikeLockConfigurationPayload {
        let response = try await transport.readConfiguration(
            request: StarkBikeLockConfigurationCommand.readPacket,
            operationName: "4005 Bike Lock read",
            allowLiveTelemetrySession: false
        )
        return try StarkBikeLockConfigurationCommand.decodeResponse(response)
    }

    private func snapshot(
        configuration: StarkBikeLockConfigurationPayload,
        firmware: StarkFirmwareVersion
    ) -> BikeSDKBikeLockControlSnapshot {
        .init(
            vcuFirmware: firmware.description,
            isLocked: configuration.isLocked,
            didPassNoOpWrite: true
        )
    }

    private func report(_ detail: String) async {
        await eventEmitter.send(.debug(.init(title: "Bike Lock", detail: detail)))
    }

    private enum Constants {
        static let writeVerificationDelay = Duration.milliseconds(150)
    }
}
