import Foundation
import StarkProtocol
import Testing

@Suite("Stark inverter temperatures decoder")
struct StarkInverterTemperaturesDecoderTests {
    @Test("Decodes eight little-endian values using the validated Celsius scale")
    func decodesValidatedTemperatures() throws {
        let payload = try StarkInverterTemperaturesDecoder().decode(
            StarkProtocolFixtures.validatedInverterTemperatures
        )

        #expect(payload.rawValues == [395, 408, 323, 519, 322, 325, 330, 0])
        #expect(payload.celsius == [39.5, 40.8, 32.3, 51.9, 32.2, 32.5, 33.0, nil])
    }

    @Test("Maps a physically confirmed 60 degree sensor and zero as unavailable")
    func mapsConfirmedTemperatureAndUnavailableSensor() throws {
        let payload = try StarkInverterTemperaturesDecoder().decode(Data([
            0x58, 0x02, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0
        ]))

        #expect(payload.celsius == [60, nil, nil, nil, nil, nil, nil, nil])
    }

    @Test("Rejects payloads shorter than all eight sensor slots")
    func rejectsShortPayload() {
        let data = Data(repeating: 0, count: StarkInverterTemperaturesPayloadLayout.requiredLength - 1)

        #expect(throws: StarkProtocolError.payloadTooShort(
            expected: StarkInverterTemperaturesPayloadLayout.requiredLength,
            actual: data.count
        )) {
            try StarkInverterTemperaturesDecoder().decode(data)
        }
    }
}
