import DesignSystem
import SwiftUI

struct OnboardingHeroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var scaledTitleSize = Constants.titleSize
    @State private var dragTranslation = CGSize.zero
    @State private var presentationPhase = OnboardingHeroPresentationPhase.initial
    @State private var ambientProgress = 0.0

    let onContinue: () -> Void
    var onExploreDemo: (() -> Void)?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                heroImage(size: proxy.size)
                    .ignoresSafeArea()
                OnboardingHeroAtmosphereView(
                    isLightPresented: presentationPhase.includes(.light),
                    ambientProgress: ambientProgress,
                    parallaxOffset: atmosphereParallaxOffset,
                    reduceMotion: accessibilityAnimationDisabled
                )
                .ignoresSafeArea()
                OnboardingHeroImageTreatment(usesOpaqueTreatment: reduceTransparency)
                    .ignoresSafeArea()
                content(size: proxy.size)
            }
            .foregroundStyle(.white)
            .contentShape(Rectangle())
            .simultaneousGesture(parallaxGesture, isEnabled: !reduceMotion && !voiceOverEnabled)
        }
        .task(id: accessibilityAnimationDisabled) { await present() }
    }

    private func heroImage(size: CGSize) -> some View {
        Image("OnboardingTrailHero", bundle: .bikeOnboarding)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .scaleEffect(
                presentationPhase.includes(.photo) || reduceMotion
                    ? Constants.presentedImageScale
                    : Constants.initialImageScale
            )
            .offset(backgroundParallaxOffset)
            .opacity(presentationPhase.includes(.photo) || reduceMotion ? 1 : 0)
            .accessibilityHidden(true)
    }

    private func content(size: CGSize) -> some View {
        let contentWidth = max(.zero, size.width - Constants.horizontalPadding * 2)

        return ZStack {
            brand
                .frame(width: contentWidth, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, Constants.brandTopPadding)

            heroCopy
                .frame(width: contentWidth, alignment: .center)

            VStack(spacing: DesignSpace.extraSmall) {
                continueButton
                if let onExploreDemo {
                    OnboardingDemoButton(action: onExploreDemo)
                }
            }
                .frame(width: contentWidth)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, Constants.buttonBottomPadding)
        }
        .frame(width: size.width, height: size.height, alignment: .center)
    }

    private var brand: some View {
        Text(.bikeOnboardingBrandName)
            .font(.system(size: Constants.brandSize, weight: .bold))
            .tracking(Constants.brandTracking)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(presentationPhase.includes(.photo) || reduceMotion ? 1 : 0)
            .accessibilityLabel(.bikeOnboardingBrandName)
    }

    private var heroCopy: some View {
        VStack(spacing: Constants.copySpacing) {
            ViewThatFits(in: .horizontal) {
                titleBlock(font: titleFont)
                titleBlock(font: compactTitleFont)
                titleBlock(font: minimumTitleFont)
            }
            .frame(maxWidth: .infinity)
            .accessibilityRepresentation {
                Text(.bikeOnboardingHeroAccessibilityTitle)
                    .accessibilityAddTraits(.isHeader)
            }

            Text(.bikeOnboardingHeroDetail)
                .font(detailFont)
                .foregroundStyle(.white.opacity(Constants.detailOpacity))
                .multilineTextAlignment(.center)
                .lineSpacing(Constants.detailLineSpacing)
                .frame(maxWidth: Constants.detailMaxWidth)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(presentationPhase.includes(.detail) || reduceMotion ? 1 : 0)
                .offset(
                    y: presentationPhase.includes(.detail) || reduceMotion
                        ? 0
                        : Constants.detailInitialOffset
                )
        }
        .padding(.vertical, Constants.copyScrimVerticalPadding)
        .background(copyScrim)
    }

    private func titleBlock(font: Font) -> some View {
        VStack(spacing: Constants.titleSpacing) {
            revealedTitleLine(
                BikeOnboardingL10n.text(.bikeOnboardingHeroTitleConnected),
                font: font,
                isPresented: presentationPhase.includes(.connected)
            )
            revealedTitleLine(
                BikeOnboardingL10n.text(.bikeOnboardingHeroTitleRiding),
                font: font,
                isPresented: presentationPhase.includes(.riding)
            )
        }
    }

    private func revealedTitleLine(_ title: String, font: Font, isPresented: Bool) -> some View {
        Text(title)
            .font(font)
            .tracking(dynamicTypeSize.isAccessibilitySize ? 0 : Constants.titleTracking)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .allowsTightening(true)
            .fixedSize(horizontal: true, vertical: true)
            .offset(y: isPresented || reduceMotion ? 0 : Constants.titleInitialOffset)
            .mask(alignment: .bottom) {
                Rectangle()
                    .scaleEffect(y: isPresented || reduceMotion ? 1 : 0, anchor: .bottom)
            }
    }

    private var titleFont: Font {
        if dynamicTypeSize.isAccessibilitySize {
            return .title2.weight(.bold)
        }
        return .system(size: min(scaledTitleSize, Constants.maximumTitleSize), weight: .bold)
    }

    private var compactTitleFont: Font {
        .system(size: min(scaledTitleSize, Constants.compactTitleSize), weight: .bold)
    }

    private var minimumTitleFont: Font {
        .system(size: Constants.minimumTitleSize, weight: .bold)
    }

    private var detailFont: Font {
        dynamicTypeSize.isAccessibilitySize ? .footnote.weight(.medium) : .callout.weight(.medium)
    }

    private var copyScrim: some View {
        Color.black
            .opacity(reduceTransparency ? Constants.opaqueCopyScrimOpacity : Constants.copyScrimOpacity)
            .blur(radius: reduceTransparency ? 0 : Constants.copyScrimBlur)
            .padding(reduceTransparency ? Constants.opaqueCopyScrimInset : Constants.copyScrimInset)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var continueButton: some View {
        OnboardingPrimaryButton(
            title: BikeOnboardingL10n.text(.bikeOnboardingActionGetStarted),
            systemImage: "arrow.right",
            action: onContinue
        )
        .environment(\.colorScheme, .dark)
        .scaleEffect(presentationPhase.includes(.complete) || reduceMotion ? 1 : Constants.buttonInitialScale)
        .opacity(presentationPhase.includes(.complete) || reduceMotion ? 1 : 0)
        .accessibilityHint(.bikeOnboardingAccessibilityGetStartedHint)
    }
}

private extension OnboardingHeroView {
    private var backgroundParallaxOffset: CGSize {
        parallaxOffset(maximum: Constants.backgroundParallax)
    }

    private var atmosphereParallaxOffset: CGSize {
        parallaxOffset(maximum: Constants.atmosphereParallax)
    }

    private func parallaxOffset(maximum: CGFloat) -> CGSize {
        CGSize(
            width: dragTranslation.width / Constants.maximumHorizontalDrag * maximum,
            height: dragTranslation.height / Constants.maximumVerticalDrag * maximum
        )
    }

    private var accessibilityAnimationDisabled: Bool {
        reduceMotion || voiceOverEnabled
    }

    private var parallaxGesture: some Gesture {
        DragGesture(minimumDistance: Constants.minimumDragDistance)
            .onChanged { value in
                dragTranslation = CGSize(
                    width: clamped(value.translation.width, limit: Constants.maximumHorizontalDrag),
                    height: clamped(value.translation.height, limit: Constants.maximumVerticalDrag)
                )
            }
            .onEnded { _ in
                withAnimation(.spring(response: Constants.parallaxReturnResponse, dampingFraction: 0.84)) {
                    dragTranslation = .zero
                }
            }
    }

    private func clamped(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        min(limit, max(-limit, value))
    }

    @MainActor
    private func present() async {
        guard !accessibilityAnimationDisabled else {
            presentStaticFrame()
            return
        }

        for step in OnboardingHeroTimeline.standard.steps {
            guard await wait(for: step.delay) else { return }
            withAnimation(.easeOut(duration: step.animationDuration)) {
                presentationPhase = step.phase
            }
        }

        withAnimation(.linear(duration: Constants.ambientDuration)) {
            ambientProgress = 1
        }
    }

    @MainActor
    private func presentStaticFrame() {
        presentationPhase = .complete
        ambientProgress = 1
    }

    private func wait(for duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

private extension OnboardingHeroView {
    enum Constants {
        static let initialImageScale: CGFloat = 1.08
        static let presentedImageScale: CGFloat = 1.04
        static let backgroundParallax: CGFloat = 4
        static let atmosphereParallax: CGFloat = 18
        static let horizontalPadding: CGFloat = 24
        static let brandTopPadding: CGFloat = 12
        static let brandSize: CGFloat = 13
        static let brandTracking: CGFloat = 4.2
        static let copySpacing: CGFloat = 20
        static let titleSpacing: CGFloat = -8
        static let titleSize: CGFloat = 58
        static let maximumTitleSize: CGFloat = 72
        static let compactTitleSize: CGFloat = 48
        static let minimumTitleSize: CGFloat = 40
        static let titleTracking: CGFloat = -2.1
        static let titleInitialOffset: CGFloat = 28
        static let detailOpacity = 0.96
        static let detailLineSpacing: CGFloat = 3
        static let detailMaxWidth: CGFloat = 330
        static let detailInitialOffset: CGFloat = 10
        static let copyScrimOpacity = 0.5
        static let opaqueCopyScrimOpacity = 1.0
        static let copyScrimVerticalPadding: CGFloat = 52
        static let copyScrimBlur: CGFloat = 48
        static let copyScrimInset: CGFloat = -28
        static let opaqueCopyScrimInset: CGFloat = -18
        static let buttonBottomPadding: CGFloat = 18
        static let buttonInitialScale: CGFloat = 0.98
        static let minimumDragDistance: CGFloat = 6
        static let maximumHorizontalDrag: CGFloat = 48
        static let maximumVerticalDrag: CGFloat = 36
        static let parallaxReturnResponse = 0.38
        static let ambientDuration = 5.5
    }
}
