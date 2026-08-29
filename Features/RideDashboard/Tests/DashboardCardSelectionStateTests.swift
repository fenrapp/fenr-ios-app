@testable import RideDashboard
import Testing

@Suite("Dashboard card selection state")
struct DashboardCardSelectionStateTests {
    @Test("Shows compact speed only on a secondary card when enabled")
    func resolvesCompactSpeedVisibility() {
        var selection = DashboardCardSelectionState()

        #expect(!selection.showsCompactSpeed(true))
        selection.ridingCard = .range
        #expect(!selection.showsCompactSpeed(false))
        #expect(selection.showsCompactSpeed(true))
    }

    @Test("Resets only pages belonging to hidden cards")
    func resetsOnlyHiddenPages() {
        var selection = DashboardCardSelectionState(
            ridingCard: .currentTrip,
            currentTripPage: .statistics,
            efficiencyPage: .trend,
            rangePage: .battery,
            systemHealthPage: .thermal,
            dynamicsPage: .course
        )

        selection.resetHiddenPages(in: .riding)

        #expect(selection.currentTripPage == .statistics)
        #expect(selection.efficiencyPage == .live)
        #expect(selection.rangePage == .range)
        #expect(selection.systemHealthPage == .health)
        #expect(selection.dynamicsPage == .lean)
        #expect(!selection.needsHiddenPageReset(in: .riding))
    }

    @Test("Resets every internal page outside riding mode")
    func resetsAllPagesWhileCharging() {
        var selection = DashboardCardSelectionState(
            ridingCard: .efficiency,
            currentTripPage: .statistics,
            efficiencyPage: .trend,
            rangePage: .battery,
            systemHealthPage: .cells,
            dynamicsPage: .pitch
        )

        #expect(selection.needsHiddenPageReset(in: .charging))
        selection.resetHiddenPages(in: .charging)

        #expect(selection.currentTripPage == .current)
        #expect(selection.efficiencyPage == .live)
        #expect(selection.rangePage == .range)
        #expect(selection.systemHealthPage == .health)
        #expect(selection.dynamicsPage == .lean)
    }
}
