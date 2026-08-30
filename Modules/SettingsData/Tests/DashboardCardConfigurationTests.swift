import Foundation
import SettingsDomain
import Testing

@Suite("Dashboard card configuration")
struct DashboardCardConfigurationTests {
    @Test("Provides every card visible in the production order")
    func providesDefaults() {
        let configuration = DashboardCardConfiguration()

        #expect(configuration.sections.map(\.id) == DashboardCardSectionID.defaultOrder)
        #expect(configuration.sections.filter(\.isVisible).count == configuration.sections.count)
        let pages = configuration.sections.flatMap(\.pages)
        #expect(pages.filter(\.isVisible).count == pages.count)
    }

    @Test("Normalizes duplicates, missing cards, and empty visible page sets")
    func normalizesSavedConfiguration() {
        let configuration = DashboardCardConfiguration(sections: [
            .init(
                id: .efficiency,
                isVisible: false,
                pages: [
                    .init(id: .efficiencyTrend, isVisible: false),
                    .init(id: .efficiencyTrend, isVisible: true),
                    .init(id: .efficiencyLive, isVisible: false)
                ]
            ),
            .init(id: .efficiency),
            .init(id: .currentTrip)
        ])

        #expect(configuration.sections.map(\.id) == [
            .bikeLock, .navigation, .efficiency, .currentTrip, .range, .systemHealth, .rideDynamics
        ])
        let efficiency = configuration.section(id: .efficiency)
        #expect(!efficiency.isVisible)
        #expect(efficiency.pages.map(\.id) == [.efficiencyTrend, .efficiencyLive])
        #expect(efficiency.pages.map(\.isVisible) == [true, false])
    }

    @Test("Ignores unknown saved identifiers and restores known defaults")
    func ignoresUnknownIdentifiers() throws {
        let data = Data("""
        {
          "sections": [
            { "id": "futureCard", "isVisible": false, "pages": [] },
            { "id": "range", "isVisible": false, "pages": [
              { "id": "futurePage", "isVisible": true },
              { "id": "batteryTrip", "isVisible": true }
            ] }
          ]
        }
        """.utf8)

        let configuration = try JSONDecoder().decode(DashboardCardConfiguration.self, from: data)

        #expect(configuration.sections.map(\.id) == [
            .bikeLock, .navigation, .range, .currentTrip, .efficiency, .systemHealth, .rideDynamics
        ])
        #expect(!configuration.section(id: .range).isVisible)
        #expect(configuration.section(id: .range).pages.map(\.id) == [.batteryTrip, .range])
    }

    @Test("Prevents hiding the final visible page")
    func preventsHidingFinalPage() {
        var configuration = DashboardCardConfiguration()

        let didHideCurrentTrip = configuration.setPageVisibility(
            false,
            id: .currentTrip,
            sectionID: .currentTrip
        )
        let didHideStatistics = configuration.setPageVisibility(
            false,
            id: .rideStatistics,
            sectionID: .currentTrip
        )
        #expect(didHideCurrentTrip)
        #expect(!didHideStatistics)
        #expect(configuration.section(id: .currentTrip).pages.filter(\.isVisible).map(\.id) == [.rideStatistics])
    }
}
