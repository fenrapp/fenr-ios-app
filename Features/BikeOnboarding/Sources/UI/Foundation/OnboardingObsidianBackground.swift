import SwiftUI

struct OnboardingObsidianBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            backgroundColor
            RadialGradient(
                colors: [glowColor.opacity(Constants.upperGlowOpacity), .clear],
                center: .topTrailing,
                startRadius: .zero,
                endRadius: Constants.upperGlowRadius
            )
            RadialGradient(
                colors: [glowColor.opacity(Constants.lowerGlowOpacity), .clear],
                center: .bottomLeading,
                startRadius: .zero,
                endRadius: Constants.lowerGlowRadius
            )
        }
        .ignoresSafeArea()
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : Color(white: Constants.lightBackgroundWhite)
    }

    private var glowColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

private extension OnboardingObsidianBackground {
    enum Constants {
        static let upperGlowOpacity = 0.16
        static let lowerGlowOpacity = 0.08
        static let upperGlowRadius: CGFloat = 420
        static let lowerGlowRadius: CGFloat = 360
        static let lightBackgroundWhite = 0.96
    }
}
