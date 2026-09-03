@testable import RideNavigation
import SwiftUI
import Testing

struct RideNavigationFocusPaletteTests {
    @Test("Focus surface colors follow the system appearance")
    func paletteFollowsColorScheme() {
        let dark = RideNavigationFocusPalette(colorScheme: .dark)
        let light = RideNavigationFocusPalette(colorScheme: .light)

        #expect(dark.backgroundWhiteLevel == 0)
        #expect(dark.foregroundWhiteLevel == 1)
        #expect(light.backgroundWhiteLevel == 1)
        #expect(light.foregroundWhiteLevel == 0)
    }
}
