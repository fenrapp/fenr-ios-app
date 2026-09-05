import Foundation
import SettingsDomain
import Testing

@Suite("Dashboard card configuration")
struct DashboardCardConfigurationTests {
    @Test("Provides every card visible in the production order")
    func providesDefaults() {
        let configuration = DashboardCardConfiguration()

        #expect(configuration.sections.map(\.id) == DashboardCardSectionID.defaultOrder)
        #expect(configuration.section(id: .rideDynamics).pages.map(\.id) == [.lean, .pitch, .altitude, .course])
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
            .bikeLock, .navigation, .efficiency, .currentTrip, .range, .systemHealth, .rideDynamics, .settings
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
            .bikeLock, .navigation, .range, .currentTrip, .efficiency, .systemHealth, .rideDynamics, .settings
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

extension DashboardCardConfigurationTests {
    @Test("Adds altitude to existing settings without changing saved order or visibility")
    func upgradesDynamicsPages() throws {
        let data = Data("""
        {"sections":[{"id":"rideDynamics","isVisible":false,"pages":[
        {"id":"course","isVisible":true},{"id":"pitch","isVisible":false},{"id":"lean","isVisible":true}
        ]}]}
        """.utf8)
        var configuration = try JSONDecoder().decode(DashboardCardConfiguration.self, from: data)
        let section = configuration.section(id: .rideDynamics)
        #expect(!section.isVisible)
        #expect(section.pages.map(\.id) == [.altitude, .course, .pitch, .lean])
        #expect(section.pages.map(\.isVisible) == [true, true, false, true])
        let didHide = configuration.setPageVisibility(false, id: .altitude, sectionID: .rideDynamics)
        #expect(didHide)
        configuration.setPageOrder([.altitude, .course, .lean, .pitch], sectionID: .rideDynamics)
        let restored = try JSONDecoder().decode(
            DashboardCardConfiguration.self, from: JSONEncoder().encode(configuration)
        )
        #expect(restored == configuration)
    }
}

extension DashboardCardConfigurationTests {
    @Test("Settings defaults to last, can be reordered, and cannot be hidden even by saved data")
    func settingsRemainsReachable() throws {
        var configuration = DashboardCardConfiguration()
        #expect(configuration.sections.last?.id == .settings)
        configuration.setSectionOrder([.settings, .rideDynamics])
        configuration.setSectionVisibility(false, id: .settings)
        #expect(configuration.sections.first?.id == .settings)
        #expect(configuration.section(id: .settings).isVisible)
        let restored = try JSONDecoder().decode(DashboardCardConfiguration.self, from: Data("""
        {"sections":[{"id":"settings","isVisible":false},{"id":"navigation","isVisible":false}]}
        """.utf8))
        #expect(restored.section(id: .settings).isVisible)
        #expect(!restored.section(id: .navigation).isVisible)
        #expect(restored.sections.first { $0.id != .bikeLock }?.id == .settings)
    }
}
