import SwiftUI

struct OnboardingHeroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var scaledTitleSize = Constants.titleSize
    @State private var dragTranslation = CGSize.zero
    @State private var isLightPresented = false
    @State private var isPhotoPresented = false
    @State private var isBrandPresented = false
    @State private var isConnectedPresented = false
    @State private var isRidingPresented = false
    @State private var isDetailPresented = false
    @State private var isButtonPresented = false
    @State private var ambientProgress = 0.0

    let onContinue: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                heroImage(size: proxy.size)
                    .ignoresSafeArea()
                OnboardingHeroAtmosphereView(
                    isLightPresented: isLightPresented,
                    ambientProgress: ambientProgress,
                    parallaxOffset: atmosphereParallaxOffset,
                    reduceMotion: accessibilityAnimationDisabled
                )
                .ignoresSafeArea()
                imageTreatment
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
            .scaleEffect(isPhotoPresented || reduceMotion ? Constants.presentedImageScale : Constants.initialImageScale)
            .offset(backgroundParallaxOffset)
            .opacity(isPhotoPresented || reduceMotion ? 1 : 0)
            .accessibilityHidden(true)
    }

    private var imageTreatment: some View {
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

    private func content(size: CGSize) -> some View {
        let contentWidth = max(.zero, size.width - Constants.horizontalPadding * 2)

        return ZStack {
            brand
                .frame(width: contentWidth, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, Constants.brandTopPadding)

            heroCopy
                .frame(width: contentWidth, alignment: .center)

            continueButton
                .frame(width: contentWidth)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, Constants.buttonBottomPadding)
        }
        .frame(width: size.width, height: size.height, alignment: .center)
    }

    private var brand: some View {
        Text("FENR")
            .font(.system(size: Constants.brandSize, weight: .bold))
            .tracking(Constants.brandTracking)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isBrandPresented || reduceMotion ? 1 : 0)
            .accessibilityLabel("FENR")
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
                Text("Connected Riding")
                    .accessibilityAddTraits(.isHeader)
            }

            Text("Live telemetry, battery health and bike controls. All in one place.")
                .font(detailFont)
                .foregroundStyle(.white.opacity(Constants.detailOpacity))
                .multilineTextAlignment(.center)
                .lineSpacing(Constants.detailLineSpacing)
                .frame(maxWidth: Constants.detailMaxWidth)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(isDetailPresented || reduceMotion ? 1 : 0)
                .offset(y: isDetailPresented || reduceMotion ? 0 : Constants.detailInitialOffset)
        }
        .padding(.vertical, Constants.copyScrimVerticalPadding)
        .background(copyScrim)
    }

    private func titleBlock(font: Font) -> some View {
        VStack(spacing: Constants.titleSpacing) {
            revealedTitleLine("CONNECTED", font: font, isPresented: isConnectedPresented)
            revealedTitleLine("RIDING", font: font, isPresented: isRidingPresented)
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
            title: "Get Started",
            systemImage: "arrow.right",
            action: onContinue
        )
        .environment(\.colorScheme, .dark)
        .scaleEffect(isButtonPresented || reduceMotion ? 1 : Constants.buttonInitialScale)
        .opacity(isButtonPresented || reduceMotion ? 1 : 0)
        .accessibilityHint("Starts bike setup")
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

    private var bottomShadeOpacity: Double {
        reduceTransparency ? Constants.opaqueBottomShadeOpacity : Constants.bottomShadeOpacity
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

        withAnimation(.easeOut(duration: Constants.lightRevealDuration)) {
            isLightPresented = true
        }

        guard await wait(for: Constants.photoRevealDelay) else { return }
        withAnimation(.easeOut(duration: Constants.photoRevealDuration)) {
            isPhotoPresented = true
            isBrandPresented = true
        }

        guard await wait(for: Constants.titleRevealDelay) else { return }
        withAnimation(.easeOut(duration: Constants.titleRevealDuration)) {
            isConnectedPresented = true
        }

        guard await wait(for: Constants.titleLineDelay) else { return }
        withAnimation(.easeOut(duration: Constants.titleRevealDuration)) {
            isRidingPresented = true
        }

        guard await wait(for: Constants.detailRevealDelay) else { return }
        withAnimation(.easeOut(duration: Constants.detailRevealDuration)) {
            isDetailPresented = true
        }

        guard await wait(for: Constants.buttonRevealDelay) else { return }
        withAnimation(.easeOut(duration: Constants.buttonRevealDuration)) {
            isButtonPresented = true
        }

        withAnimation(.linear(duration: Constants.ambientDuration)) {
            ambientProgress = 1
        }
    }

    @MainActor
    private func presentStaticFrame() {
        isLightPresented = true
        isPhotoPresented = true
        isBrandPresented = true
        isConnectedPresented = true
        isRidingPresented = true
        isDetailPresented = true
        isButtonPresented = true
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
        static let topShadeOpacity = 0.52
        static let topClearLocation = 0.2
        static let middleShadeOpacity = 0.42
        static let middleShadeLocation = 0.52
        static let bottomShadeOpacity = 0.94
        static let opaqueBottomShadeOpacity = 0.98
        static let sideShadeOpacity = 0.2
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
        static let lightRevealDuration = 0.18
        static let photoRevealDelay: Duration = .milliseconds(160)
        static let photoRevealDuration = 0.7
        static let titleRevealDelay: Duration = .milliseconds(270)
        static let titleLineDelay: Duration = .milliseconds(70)
        static let titleRevealDuration = 0.32
        static let detailRevealDelay: Duration = .milliseconds(120)
        static let detailRevealDuration = 0.25
        static let buttonRevealDelay: Duration = .milliseconds(80)
        static let buttonRevealDuration = 0.2
        static let ambientDuration = 5.5
    }
}
