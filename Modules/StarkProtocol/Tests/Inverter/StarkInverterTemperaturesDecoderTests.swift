import Foundation
import StarkProtocol
import Testing

@Suite("Stark inverter temperatures decoder")
struct StarkInverterTemperaturesDecoderTests {
    @Test("Separates six temperature readings from both groups of status bytes")
    func decodesTemperaturesAndStatus() throws {
        let payload = try StarkInverterTemperaturesDecoder().decode(
            StarkProtocolFixtures.inverterTemperaturesWithStatus
        )

        #expect(payload.rawValues == [395, 408, 323, 322, 325, 330])
        #expect(payload.celsius == [39.5, 40.8, 32.3, 32.2, 32.5, 33.0])
        #expect(payload.motor.validStatus == 7)
        #expect(payload.motor.usedStatus == 2)
        #expect(payload.igbt.validStatus == 0)
        #expect(payload.igbt.usedStatus == 0)
    }

    @Test("Maps a physically confirmed 60 degree sensor and zero as unavailable")
    func mapsConfirmedTemperatureAndUnavailableSensor() throws {
        let payload = try StarkInverterTemperaturesDecoder().decode(Data([
            0x58, 0x02, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0
        ]))

        #expect(payload.celsius == [60, nil, nil, nil, nil, nil])
    }

    @Test("Status bytes cannot inflate temperature statistics", arguments: [UInt8(0), 2, 7, 48, 255])
    func excludesStatusFromStatistics(status: UInt8) throws {
        let payload = try StarkInverterTemperaturesDecoder().decode(Data([
            240, 0, 250, 0, 4, 1, status, status,
            14, 1, 14, 1, 24, 1, status, status
        ]))
        let temperatures = payload.celsius.compactMap { $0 }

        #expect(payload.rawValues == [240, 250, 260, 270, 270, 280])
        #expect(temperatures.min() == 24)
        #expect(temperatures.max() == 28)
        #expect((temperatures.reduce(0, +) / Double(temperatures.count)).rounded() == 26)
        #expect(payload.motor.validStatus == status)
        #expect(payload.motor.usedStatus == status)
        #expect(payload.igbt.validStatus == status)
        #expect(payload.igbt.usedStatus == status)
    }

    @Test("Nonzero status does not create readings when every temperature is unavailable")
    func keepsUnavailableSensorsSeparateFromStatus() throws {
        let payload = try StarkInverterTemperaturesDecoder().decode(Data([
            0, 0, 0, 0, 0, 0, 7, 2,
            0, 0, 0, 0, 0, 0, 255, 48
        ]))

        #expect(payload.rawValues == [0, 0, 0, 0, 0, 0])
        #expect(payload.celsius == [nil, nil, nil, nil, nil, nil])
        #expect(payload.igbt.validStatus == 255)
        #expect(payload.igbt.usedStatus == 48)
    }

    @Test("Rejects payloads shorter than both complete sensor groups")
    func rejectsShortPayload() {
        let data = Data(repeating: 0, count: StarkInverterTemperaturesPayloadLayout.requiredLength - 1)

        #expect(throws: StarkProtocolError.invalidPayloadLength(
            expected: StarkInverterTemperaturesPayloadLayout.requiredLength,
            actual: data.count
        )) {
            try StarkInverterTemperaturesDecoder().decode(data)
        }
    }

    @Test("Rejects payloads longer than both complete sensor groups")
    func rejectsLongPayload() {
        let data = Data(repeating: 0, count: StarkInverterTemperaturesPayloadLayout.requiredLength + 1)

        #expect(throws: StarkProtocolError.invalidPayloadLength(
            expected: StarkInverterTemperaturesPayloadLayout.requiredLength,
            actual: data.count
        )) {
            try StarkInverterTemperaturesDecoder().decode(data)
        }
    }
}
