import SwiftUI

struct RideNavigationFocusPalette {
    let backgroundWhiteLevel: Double
    let foregroundWhiteLevel: Double

    init(colorScheme: ColorScheme) {
        switch colorScheme {
        case .dark:
            backgroundWhiteLevel = .zero
            foregroundWhiteLevel = 1
        case .light:
            backgroundWhiteLevel = 1
            foregroundWhiteLevel = .zero
        @unknown default:
            backgroundWhiteLevel = .zero
            foregroundWhiteLevel = 1
        }
    }

    var background: Color { Color(white: backgroundWhiteLevel) }
    var foreground: Color { Color(white: foregroundWhiteLevel) }
}
