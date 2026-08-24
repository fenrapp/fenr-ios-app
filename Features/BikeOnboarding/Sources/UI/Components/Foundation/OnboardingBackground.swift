import DesignSystem
import SwiftUI

struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            LinearGradient(
                colors: [
                    DesignColor.accent.opacity(Constants.accentWashOpacity),
                    Color.clear,
                    DesignColor.informational.opacity(Constants.infoWashOpacity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

private enum Constants {
    static let accentWashOpacity = 0.18
    static let infoWashOpacity = 0.08
}
