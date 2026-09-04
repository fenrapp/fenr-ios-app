import Foundation
import SettingsDomain
import Testing

@Suite("Ride navigation settings")
struct RideNavigationSettingsTests {
    @Test("Decodes legacy ride navigation settings with heading up")
    func decodesLegacyRideNavigationSettings() throws {
        let data = Data("""
        {
          "avoidsTolls": true,
          "avoidsHighways": false,
          "preferredMapStyle": "standard"
        }
        """.utf8)

        let settings = try JSONDecoder().decode(RideNavigationSettings.self, from: data)

        #expect(settings.mapOrientation == .headingUp)
        #expect(settings.miniMapPosition == .topTrailing)
        #expect(settings.miniMapScale == .initial)
        #expect(settings.miniMapLayoutOrientation == .portrait)
        #expect(!settings.showsGuidanceInFocus)
        #expect(!settings.showsCompassRing)
        #expect(!settings.showsRoadsInFocus)
        #expect(settings.lineAppearances == RideNavigationLineAppearances())
    }

    @Test("Round trips navigation visibility and route appearances")
    func roundTripsNavigationAppearanceSettings() throws {
        var appearances = RideNavigationLineAppearances()
        appearances[.pendingRoute] = RideNavigationLineAppearance(
            color: RideNavigationLineColor(red: 0.15, green: 0.45, blue: 0.75),
            thickness: .thin
        )
        appearances[.connector] = RideNavigationLineAppearance(
            color: RideNavigationLineColor(red: 0.8, green: 0.2, blue: 0.1),
            thickness: .thick
        )
        let settings = RideNavigationSettings(
            showsGuidanceInFocus: true,
            showsCompassRing: true,
            showsRoadsInFocus: true,
            lineAppearances: appearances
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(RideNavigationSettings.self, from: data)

        #expect(decoded == settings)
    }

    @Test("Normalizes opaque sRGB route colors")
    func normalizesRouteColors() throws {
        let color = RideNavigationLineColor(
            red: -.infinity,
            green: 1.5,
            blue: .nan
        )

        #expect(color.red == 0)
        #expect(color.green == 1)
        #expect(color.blue == 0)

        let decoded = try JSONDecoder().decode(
            RideNavigationLineColor.self,
            from: Data(#"{"red":-2,"green":0.5,"blue":8}"#.utf8)
        )
        #expect(decoded == RideNavigationLineColor(red: 0, green: 0.5, blue: 1))
    }

    @Test("Migrates a saved mini map corner to its normalized position")
    func migratesLegacyMiniMapCorner() throws {
        let data = Data(#"{"miniMapCorner":"bottomLeading"}"#.utf8)

        let settings = try JSONDecoder().decode(RideNavigationSettings.self, from: data)

        #expect(settings.miniMapPosition == MiniMapPosition(
            horizontalFraction: 0.15,
            verticalFraction: 0.65
        ))
    }

    @Test("Clamps a persisted mini map position to normalized screen coordinates")
    func clampsMiniMapPositionToScreen() throws {
        let data = Data(#"{"horizontalFraction":-0.4,"verticalFraction":1.8}"#.utf8)

        let position = try JSONDecoder().decode(MiniMapPosition.self, from: data)

        #expect(position.horizontalFraction == 0)
        #expect(position.verticalFraction == 1)
    }

    @Test("Clamps the persisted mini map scale to its supported range", arguments: [
        (0.2, MiniMapScale.minimumValue),
        (2.0, MiniMapScale.maximumValue)
    ])
    func clampsMiniMapScale(rawValue: Double, expected: Double) throws {
        let data = Data(String(rawValue).utf8)

        let scale = try JSONDecoder().decode(MiniMapScale.self, from: data)

        #expect(scale.value == expected)
    }
}
