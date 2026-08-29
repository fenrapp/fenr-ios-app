import Foundation
import StarkProtocol
import Testing

@Suite("Bike lock configuration command")
struct StarkBikeLockConfigurationCommandTests {
    @Test("Encodes read, lock, and unlock packets")
    func encodesPackets() {
        #expect(StarkBikeLockConfigurationCommand.readPacket == Data([0, 5]))
        #expect(StarkBikeLockConfigurationCommand.writePacket(isLocked: true) == Data([1, 5, 0x83, 1, 1, 0, 0]))
        #expect(StarkBikeLockConfigurationCommand.writePacket(isLocked: false) == Data([1, 5, 0x83, 0, 1, 0, 0]))
    }

    @Test("Preserves lock type and timeout in a no-op write")
    func preservesSiblingValues() {
        let configuration = StarkBikeLockConfigurationPayload(
            isLocked: true,
            lockType: 3,
            timeoutSeconds: -2
        )

        #expect(
            StarkBikeLockConfigurationCommand.noOpWritePacket(configuration: configuration)
                == Data([1, 5, 0x83, 1, 3, 0xFE, 0xFF])
        )
    }

    @Test("Decodes confirmed state and signed timeout")
    func decodesResponse() throws {
        let payload = try StarkBikeLockConfigurationCommand.decodeResponse(
            Data([2, 5, 0, 1, 1, 30, 0])
        )

        #expect(payload == .init(isLocked: true, lockType: 1, timeoutSeconds: 30))
    }

    @Test("Rejects unknown lock status")
    func rejectsUnknownStatus() {
        #expect(throws: StarkProtocolError.invalidBikeLockStatus(2)) {
            try StarkBikeLockConfigurationCommand.decodeResponse(Data([2, 5, 0, 2, 1, 0, 0]))
        }
    }

    @Test("Firmware gate starts at 1.6.29")
    func firmwareGate() {
        #expect(!StarkFirmwareVersion(major: 1, minor: 6, patch: 28).isBikeLockControlCompatible)
        #expect(StarkFirmwareVersion(major: 1, minor: 6, patch: 29).isBikeLockControlCompatible)
    }
}
