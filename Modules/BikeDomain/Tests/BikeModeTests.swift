import BikeDomain
import Testing

@Suite("Bike mode")
struct BikeModeTests {
    @Test("Maps display modes to zero-based configuration indexes", arguments: [
        (BikeMode.index(1), 0),
        (BikeMode.index(5), 4),
        (BikeMode.index(0), nil),
        (BikeMode.index(6), nil),
        (BikeMode.unknown, nil)
    ])
    func powerModeConfigurationIndex(mode: BikeMode, expected: Int?) {
        #expect(mode.powerModeConfigurationIndex == expected)
    }
}
