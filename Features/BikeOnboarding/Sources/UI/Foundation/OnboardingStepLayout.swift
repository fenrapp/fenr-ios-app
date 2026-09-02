import SwiftUI

struct OnboardingStepLayout<Content: View, Footer: View>: View {
    let eyebrow: String
    let title: String
    let detail: String
    private let content: Content
    private let footer: Footer

    init(
        eyebrow: String,
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: .zero) {
            ScrollView {
                VStack(alignment: .leading, spacing: OnboardingStepLayoutConstants.sectionSpacing) {
                    VStack(alignment: .leading, spacing: OnboardingStepLayoutConstants.headingSpacing) {
                        Text(eyebrow)
                            .font(.caption.weight(.bold))
                            .tracking(OnboardingStepLayoutConstants.eyebrowTracking)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(title)
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text(detail)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    content
                }
                .frame(maxWidth: OnboardingStepLayoutConstants.maxWidth, alignment: .leading)
                .padding(.horizontal, OnboardingStepLayoutConstants.horizontalPadding)
                .padding(.top, OnboardingStepLayoutConstants.topPadding)
                .padding(.bottom, OnboardingStepLayoutConstants.scrollBottomPadding)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            footer
                .frame(maxWidth: OnboardingStepLayoutConstants.maxWidth)
                .padding(.horizontal, OnboardingStepLayoutConstants.horizontalPadding)
                .padding(.bottom, OnboardingStepLayoutConstants.footerBottomPadding)
        }
    }
}

private enum OnboardingStepLayoutConstants {
    static let maxWidth: CGFloat = 520
    static let sectionSpacing: CGFloat = 28
    static let headingSpacing: CGFloat = 10
    static let eyebrowTracking: CGFloat = 2.4
    static let horizontalPadding: CGFloat = 24
    static let topPadding: CGFloat = 28
    static let scrollBottomPadding: CGFloat = 20
    static let footerBottomPadding: CGFloat = 12
}
