@testable import RideDashboard
import SettingsDomain
import Testing

@Suite("Dashboard card layout mapper")
struct DashboardCardLayoutMapperTests {
    @Test("Maps saved section and page visibility in their configured order")
    func mapsConfiguration() {
        var configuration = DashboardCardConfiguration()
        configuration.setSectionOrder([
            .bikeLock, .navigation, .range, .rideDynamics, .currentTrip, .efficiency, .systemHealth
        ])
        configuration.setSectionVisibility(false, id: .efficiency)
        configuration.setPageOrder([.batteryTrip, .range], sectionID: .range)
        configuration.setPageVisibility(false, id: .range, sectionID: .range)
        configuration.setPageOrder([.course, .lean, .pitch], sectionID: .rideDynamics)

        let layout = DashboardCardLayoutMapper().map(configuration)

        #expect(layout.ridingCards == [
            .speedometer, .bikeLock, .navigation, .range, .dynamics, .currentTrip, .systemHealth
        ])
        #expect(layout.rangePages == [.battery])
        #expect(layout.dynamicsPages == [.course, .lean, .pitch])
        #expect(layout.efficiencyPages == [.live, .trend])
    }

    @Test("Keeps only the speedometer when every configurable section is hidden")
    func mapsSingleCardLayout() {
        var configuration = DashboardCardConfiguration()
        for sectionID in DashboardCardSectionID.allCases {
            configuration.setSectionVisibility(false, id: sectionID)
        }

        let layout = DashboardCardLayoutMapper().map(configuration)

        #expect(layout.ridingCards == [.speedometer])
    }

    @Test("Hides ride navigation when its setting is disabled")
    func hidesNavigationCard() {
        var configuration = DashboardCardConfiguration()
        configuration.setSectionVisibility(false, id: .navigation)

        let layout = DashboardCardLayoutMapper().map(configuration)

        #expect(!layout.ridingCards.contains(.navigation))
        #expect(layout.ridingCards.first == .speedometer)
    }

    @Test("Selection adopts configured first pages and falls back to speedometer")
    func selectionAdoptsLayout() {
        let layout = DashboardCardLayout(
            ridingCards: [.speedometer, .range],
            currentTripPages: [.statistics],
            efficiencyPages: [.trend],
            rangePages: [.battery],
            systemHealthPages: [.thermal],
            dynamicsPages: [.course]
        )
        var selection = DashboardCardSelectionState(
            ridingCard: .efficiency,
            layout: layout
        )

        #expect(selection.ridingCard == .speedometer)
        #expect(selection.currentTripPage == .statistics)
        #expect(selection.efficiencyPage == .trend)
        #expect(selection.rangePage == .battery)
        #expect(selection.systemHealthPage == .thermal)
        #expect(selection.dynamicsPage == .course)

        selection.ridingCard = .range
        selection.rangePage = .range
        #expect(selection.needsHiddenPageReset(in: .charging, layout: layout))
        selection.resetHiddenPages(in: .charging, layout: layout)
        #expect(selection.rangePage == .battery)
    }
}
