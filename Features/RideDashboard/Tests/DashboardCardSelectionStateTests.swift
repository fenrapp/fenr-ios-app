@testable import RideDashboard
import Testing

@Suite("Dashboard card selection state")
struct DashboardCardSelectionStateTests {
    @Test("Resets only pages belonging to hidden cards")
    func resetsOnlyHiddenPages() {
        var selection = DashboardCardSelectionState(
            ridingCard: .currentTrip,
            currentTripPage: .statistics,
            efficiencyPage: .trend
        )

        selection.resetHiddenPages(in: .riding)

        #expect(selection.currentTripPage == .statistics)
        #expect(selection.efficiencyPage == .live)
        #expect(!selection.needsHiddenPageReset(in: .riding))
    }

    @Test("Resets every internal page outside riding mode")
    func resetsAllPagesWhileCharging() {
        var selection = DashboardCardSelectionState(
            ridingCard: .efficiency,
            currentTripPage: .statistics,
            efficiencyPage: .trend
        )

        #expect(selection.needsHiddenPageReset(in: .charging))
        selection.resetHiddenPages(in: .charging)

        #expect(selection.currentTripPage == .current)
        #expect(selection.efficiencyPage == .live)
    }
}
