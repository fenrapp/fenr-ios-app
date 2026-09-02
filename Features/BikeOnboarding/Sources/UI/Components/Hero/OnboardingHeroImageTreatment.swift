import SwiftUI

struct OnboardingHeroImageTreatment: View {
    let usesOpaqueTreatment: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(Constants.topShadeOpacity), location: .zero),
                    .init(color: .clear, location: Constants.topClearLocation),
                    .init(color: .black.opacity(Constants.middleShadeOpacity), location: Constants.middleShadeLocation),
                    .init(color: .black.opacity(bottomShadeOpacity), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                colors: [
                    .black.opacity(Constants.sideShadeOpacity),
                    .clear,
                    .black.opacity(Constants.sideShadeOpacity)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var bottomShadeOpacity: Double {
        usesOpaqueTreatment ? Constants.opaqueBottomShadeOpacity : Constants.bottomShadeOpacity
    }

    private enum Constants {
        static let topShadeOpacity = 0.52
        static let topClearLocation = 0.2
        static let middleShadeOpacity = 0.42
        static let middleShadeLocation = 0.52
        static let bottomShadeOpacity = 0.94
        static let opaqueBottomShadeOpacity = 0.98
        static let sideShadeOpacity = 0.2
    }
}
