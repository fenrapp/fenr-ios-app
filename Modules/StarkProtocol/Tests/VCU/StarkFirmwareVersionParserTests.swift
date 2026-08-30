import Foundation
import StarkProtocol
import Testing

@Suite("Stark firmware version parser")
struct StarkFirmwareVersionParserTests {
    @Test("ASCII version takes priority over binary representations")
    func asciiVersionTakesPriority() {
        var payload = Data([0x01, 0x09, 0x01])
        payload.append(contentsOf: Data("2.3.4".utf8))

        let version = StarkFirmwareVersionParser.parseVCUPic(from: payload)

        #expect(version == StarkFirmwareVersion(major: 2, minor: 3, patch: 4))
    }

    @Test("Version blocks take priority over binary triplets")
    func versionBlocksTakePriority() {
        let payload = Data([0x02, 0x09, 0x01, 0x00])

        let version = StarkFirmwareVersionParser.parseVCUPic(from: payload)

        #expect(version == StarkFirmwareVersion(major: 1, minor: 9, patch: 2))
    }

    @Test("Short, malformed, and zero-filled payloads contain no version information")
    func invalidPayloadsContainNoVersionInformation() {
        let shortPayload = Data([0x01, 0x02])
        let malformedPayload = Data([0x00, 0x65, 0x0A, 0x01])
        let zeroFilledPayload = Data(repeating: .zero, count: 8)

        #expect(StarkFirmwareVersionParser.parseVCUPic(from: shortPayload) == nil)
        #expect(StarkFirmwareVersionParser.parseVersionBlockDescriptions(from: shortPayload).isEmpty)
        #expect(StarkFirmwareVersionParser.parseVCUPic(from: malformedPayload) == nil)
        #expect(StarkFirmwareVersionParser.parseVersionBlockDescriptions(from: malformedPayload).isEmpty)
        #expect(StarkFirmwareVersionParser.parseVCUPic(from: zeroFilledPayload) == nil)
        #expect(StarkFirmwareVersionParser.parseVersionBlockDescriptions(from: zeroFilledPayload).isEmpty)
    }
}
