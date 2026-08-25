@testable import BikeData
import BikeDomain
import BikeSDK
import Foundation
import StarkProtocol
import Testing

@Suite("Power mode telemetry mapping")
struct PowerModeTelemetryMapperTests {
    @Test("Merges power and traction by map and promotes Alpha from positive evidence")
    func mergesConfigurationsAndDetectsAlpha() {
        let mapper = BikeSDKTelemetryPayloadToDomainMapper()
        var telemetry = BikeTelemetry(mode: .index(5))

        mapper.apply(
            .powerModeConfiguration(.init(mapIndex: 4, torqueRaw: 100, regenerationRaw: -12, curve: 3)),
            to: &telemetry,
            date: .now
        )
        mapper.apply(
            .tractionControlConfiguration(.init(mapIndex: 4, powerRaw: 125, brakingRaw: -30)),
            to: &telemetry,
            date: .now
        )

        #expect(telemetry.activePowerModeConfiguration?.horsepower == 80)
        #expect(telemetry.activePowerModeConfiguration?.regenerativeBrakingPercent == -12)
        #expect(telemetry.activePowerModeConfiguration?.powerTractionPercent == 12.5)
        #expect(telemetry.activePowerModeConfiguration?.brakingTractionPercent == -3)
        #expect(telemetry.detectedPowerTier.alphaEvidence == [
            .powerAboveStandard,
            .tractionControlConfigured
        ])
    }

    @Test("Normal regen with zero TC and 60 HP remains Standard")
    func zerosDoNotDetectAlpha() {
        let mapper = BikeSDKTelemetryPayloadToDomainMapper()
        var telemetry = BikeTelemetry()

        mapper.apply(
            .powerModeConfiguration(.init(mapIndex: 0, torqueRaw: 75, regenerationRaw: 55, curve: 0)),
            to: &telemetry,
            date: .now
        )
        mapper.apply(
            .tractionControlConfiguration(.init(mapIndex: 0, powerRaw: 0, brakingRaw: 0)),
            to: &telemetry,
            date: .now
        )

        #expect(telemetry.powerModeConfigurations[0]?.regenerativeBrakingPercent == 55)
        #expect(telemetry.detectedPowerTier == .standardBaseline)
    }
}
