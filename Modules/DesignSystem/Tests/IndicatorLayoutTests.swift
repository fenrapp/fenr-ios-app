@testable import DesignSystem
import Testing

@Suite("Design system indicator layout")
struct IndicatorLayoutTests {
    @Test("Clamps progress to the unit interval")
    func clampsProgress() {
        #expect(ProgressRingLayout.clamped(-0.2) == 0)
        #expect(ProgressRingLayout.clamped(0.65) == 0.65)
        #expect(ProgressRingLayout.clamped(1.2) == 1)
    }

    @Test("Allocates distribution widths proportionally after spacing")
    func distributionWidths() {
        let widths = SegmentedDistributionLayout.widths(
            values: [6, 3, 1],
            totalWidth: 104,
            spacing: 2,
            minimumWidth: 4
        )

        #expect(widths == [60, 30, 10])
    }

    @Test("Distribution widths keep small populated segments visible")
    func distributionMinimumWidth() {
        let widths = SegmentedDistributionLayout.widths(
            values: [999, 1],
            totalWidth: 102,
            spacing: 2,
            minimumWidth: 4
        )

        #expect(widths[0] == 96)
        #expect(widths[1] == 4)
        #expect(widths.reduce(0, +) == 100)
    }

    @Test("Distribution widths never overflow a narrow track")
    func distributionFitsNarrowTrack() {
        let widths = SegmentedDistributionLayout.widths(
            values: [1, 1, 1],
            totalWidth: 10,
            spacing: 2,
            minimumWidth: 4
        )

        #expect(widths.reduce(0, +) == 6)
        #expect(widths.allSatisfy { $0 == 2 })
    }

    @Test("Range positions clamp to the configured domain")
    func rangePositions() {
        let layout = RangeGaugeLayout(domain: -10 ... 90, width: 200)

        #expect(layout.position(-20) == 0)
        #expect(layout.position(40) == 100)
        #expect(layout.position(100) == 200)
    }

    @Test("A collapsed range has a stable origin")
    func collapsedRange() {
        let layout = RangeGaugeLayout(domain: 20 ... 20, width: 200)

        #expect(layout.position(20) == 0)
    }
}
