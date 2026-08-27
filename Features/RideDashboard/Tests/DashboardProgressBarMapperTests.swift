import BikeDomain
import Foundation
@testable import RideDashboard
import SettingsDomain
import Testing

@Suite("Dashboard progress bar mapper")
struct DashboardProgressBarMapperTests {
    private let mapper = DashboardProgressBarMapper()
    private let measurementMapper = RideDashboardMapperFactory.makeMeasurementMapper(
        measurementSystem: .metric,
        locale: Locale(identifier: "en_US")
    )

    @Test("Maps confirmed regeneration from center to the independent left scale")
    func mapsRegenerationProgress() {
        let state = map(powerWatts: -5_000)

        #expect(state == .energy(
            regenerationProgress: 0.5,
            consumptionProgress: 0,
            accessibilityLabel: "Regenerating 5 kW"
        ))
    }

    @Test("Limits regeneration progress to the active map setting")
    func limitsRegenerationToActiveMapSetting() {
        #expect(map(powerWatts: -2_000, regenerativeBrakingPercent: 40) == .energy(
            regenerationProgress: 0.2,
            consumptionProgress: 0,
            accessibilityLabel: "Regenerating 2 kW"
        ))
        #expect(map(powerWatts: -8_000, regenerativeBrakingPercent: 40) == .energy(
            regenerationProgress: 0.4,
            consumptionProgress: 0,
            accessibilityLabel: "Regenerating 8 kW"
        ))
    }

    @Test("Suppresses regeneration without a positive active map setting")
    func suppressesUnconfiguredRegeneration() {
        #expect(map(powerWatts: -5_000, regenerativeBrakingPercent: 0) == .neutralEnergy)
        #expect(map(powerWatts: -5_000, regenerativeBrakingPercent: -10) == .neutralEnergy)
        #expect(map(powerWatts: -5_000, regenerativeBrakingPercent: nil) == .neutralEnergy)
    }

    @Test("Maps consumption against the active power map")
    func mapsConsumptionProgress() {
        let state = map(
            powerWatts: 20_000,
            mode: .index(3),
            configurations: [2: .init(mapIndex: 2, horsepower: 44)]
        )

        #expect(state == .energy(
            regenerationProgress: 0,
            consumptionProgress: 0.5,
            accessibilityLabel: "Consuming 20 kW"
        ))
    }

    @Test("Uses the detected tier when active map power is unavailable")
    func mapsDetectedTierFallback() {
        let state = map(
            powerWatts: 40_000,
            detectedTier: .alpha(evidence: [.powerAboveStandard])
        )

        guard case .energy(_, let consumptionProgress, _) = state else {
            Issue.record("Expected energy progress")
            return
        }
        #expect(abs(consumptionProgress - 0.55) < 0.001)
    }

    @Test("Clamps extremes and ignores neutral or invalid power")
    func mapsEnergyProgressBoundaries() {
        #expect(map(powerWatts: -20_000) == .energy(
            regenerationProgress: 1,
            consumptionProgress: 0,
            accessibilityLabel: "Regenerating 20 kW"
        ))
        #expect(map(powerWatts: 250) == .neutralEnergy)
        #expect(map(powerWatts: .nan) == .neutralEnergy)
        #expect(map(powerWatts: 100_000) == .energy(
            regenerationProgress: 0,
            consumptionProgress: 1,
            accessibilityLabel: "Consuming 100 kW"
        ))
    }

    @Test("Preserves the original speed progress mode")
    func mapsSpeedProgressBar() {
        let state = mapper.map(
            mode: .speed,
            speedProgress: 0.5,
            telemetry: .init(),
            hasTelemetry: false,
            measurementMapper: measurementMapper
        )

        #expect(state == .speed(progress: 0.5))
    }

    @Test("Hides the progress bar without mapping telemetry")
    func mapsHiddenProgressBar() {
        let state = mapper.map(
            mode: .hidden,
            speedProgress: 0.5,
            telemetry: .init(powerTelemetry: .init(electricalPowerWatts: 20_000)),
            hasTelemetry: true,
            measurementMapper: measurementMapper
        )

        #expect(state == .hidden)
    }

    private func map(
        powerWatts: Double,
        mode: BikeMode = .index(1),
        configurations: [Int: BikePowerModeConfiguration] = [:],
        detectedTier: BikeDetectedPowerTier = .standardBaseline,
        regenerativeBrakingPercent: Double? = 100
    ) -> DashboardProgressBarViewData {
        var resolvedConfigurations = configurations
        if let configurationIndex = mode.powerModeConfigurationIndex,
           let regenerativeBrakingPercent {
            var configuration = resolvedConfigurations[configurationIndex]
                ?? .init(mapIndex: configurationIndex)
            configuration.regenerativeBrakingPercent = regenerativeBrakingPercent
            resolvedConfigurations[configurationIndex] = configuration
        }
        return mapper.map(
            mode: .energy,
            speedProgress: .zero,
            telemetry: .init(
                mode: mode,
                powerModeConfigurations: resolvedConfigurations,
                detectedPowerTier: detectedTier,
                powerTelemetry: .init(electricalPowerWatts: powerWatts)
            ),
            hasTelemetry: true,
            measurementMapper: measurementMapper
        )
    }
}
