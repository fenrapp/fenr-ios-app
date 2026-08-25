import CoreGraphics
@testable import RideDashboard
import Testing

@Suite("Charging gauge control geometry")
struct ChargingGaugeControlGeometryTests {
    private let geometry = ChargingGaugeControlGeometry(size: CGSize(width: 400, height: 200))

    @Test("Selects the nearest concentric control")
    func selectsNearestControl() {
        #expect(geometry.nearestControl(to: CGPoint(x: 200, y: 18)) == .target)
        #expect(geometry.nearestControl(to: CGPoint(x: 200, y: 50)) == .power)
        #expect(geometry.nearestControl(to: CGPoint(x: 200, y: 120)) == nil)
    }

    @Test("Maps and clamps the upper semicircle")
    func mapsUpperSemicircle() {
        #expect(geometry.progress(at: CGPoint(x: 18, y: 200)) == 0)
        #expect(geometry.progress(at: CGPoint(x: 200, y: 18)) == 0.5)
        #expect(geometry.progress(at: CGPoint(x: 382, y: 200)) == 1)
        #expect(geometry.progress(at: CGPoint(x: 100, y: 230)) == 0)
        #expect(geometry.progress(at: CGPoint(x: 300, y: 230)) == 1)
    }

    @Test("Reserves room for control thumbs above the lower edge")
    func reservesControlBottomInset() {
        #expect(geometry.center.y == 190)
        #expect(geometry.gaugeRadius == 158)
        #expect(ChargingGaugeArcGeometry.targetRadiusOffset == -ChargingGaugeArcGeometry.powerRadiusOffset)
    }

    @Test("Snaps target and power to their supported steps")
    func snapsValues() {
        #expect(
            geometry.value(
                at: CGPoint(x: 200, y: 18),
                minimum: 1,
                maximum: 100,
                step: 1
            ) == 51
        )
        #expect(
            geometry.value(
                at: CGPoint(x: 200, y: 50),
                minimum: 300,
                maximum: 3_300,
                step: 100
            ) == 1_800
        )
    }

    @Test("Locks the selected ring and emits one final intent")
    func locksControlAndFinishesOnce() {
        var interaction = makeInteraction()

        interaction.update(
            startLocation: CGPoint(x: 200, y: 18),
            location: CGPoint(x: 382, y: 200),
            geometry: geometry,
            controlState: controlState
        )
        interaction.update(
            startLocation: CGPoint(x: 200, y: 18),
            location: CGPoint(x: 18, y: 200),
            geometry: geometry,
            controlState: controlState
        )

        #expect(interaction.activeControl == .target)
        #expect(interaction.displayedPowerWatts == 1_000)
        #expect(interaction.finish() == .target(percent: 1))
        #expect(interaction.finish() == nil)
    }

    @Test("Ignores telemetry for the active ring during drag")
    func ignoresActiveTelemetryDuringDrag() {
        var interaction = makeInteraction()
        interaction.update(
            startLocation: CGPoint(x: 200, y: 50),
            location: CGPoint(x: 382, y: 200),
            geometry: geometry,
            controlState: controlState
        )

        interaction.synchronizePower(700)
        interaction.synchronizeTarget(80)

        #expect(interaction.displayedPowerWatts == 3_300)
        #expect(interaction.displayedTargetPercent == 80)
    }

    @Test("Omits intents when the final value has not changed")
    func omitsUnchangedIntents() {
        var targetInteraction = makeInteraction()
        let targetEndpoint = CGPoint(
            x: geometry.center.x + geometry.gaugeRadius + ChargingGaugeArcGeometry.targetRadiusOffset,
            y: geometry.center.y
        )
        targetInteraction.update(
            startLocation: targetEndpoint,
            location: targetEndpoint,
            geometry: geometry,
            controlState: controlState
        )

        var powerInteraction = makeInteraction()
        let powerPoint = point(
            progress: ChargingGaugeControlGeometry.normalizedProgress(
                value: 1_000,
                minimum: controlState.power.minimum,
                maximum: controlState.power.maximum
            ),
            radius: geometry.gaugeRadius + ChargingGaugeArcGeometry.powerRadiusOffset
        )
        powerInteraction.update(
            startLocation: powerPoint,
            location: powerPoint,
            geometry: geometry,
            controlState: controlState
        )

        #expect(targetInteraction.finish() == nil)
        #expect(powerInteraction.finish() == nil)
    }

    private var controlState: ChargingDashboardControlViewState {
        .init(
            isEnabled: true,
            power: .init(selected: 1_000, minimum: 300, maximum: 3_300, step: 100),
            target: .init(selected: 100, minimum: 1, maximum: 100, step: 1)
        )
    }

    private func makeInteraction() -> ChargingGaugeInteractionState {
        .init(displayedPowerWatts: 1_000, displayedTargetPercent: 100)
    }

    private func point(progress: Double, radius: CGFloat) -> CGPoint {
        let radians = .pi * (1 + progress)
        return .init(
            x: geometry.center.x + radius * cos(radians),
            y: geometry.center.y + radius * sin(radians)
        )
    }
}
