import SwiftUI
import UIKit

struct OnboardingPairingCodeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let pin: String

    @State private var surfaceVisible = false
    @State private var codeVisible = false
    @State private var lockVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.contentSpacing) {
            HStack {
                Text(.bikeOnboardingPairingCodeLabel)
                    .font(.caption.weight(.bold))
                    .tracking(Constants.labelTracking)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .font(.headline)
                    .opacity(lockVisible ? 1 : .zero)
                    .scaleEffect(lockVisible ? 1 : Constants.lockStartScale)
                    .accessibilityHidden(true)
            }

            Text(pin)
                .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                .fixedSize()
                .mask(alignment: .leading) {
                    Rectangle()
                        .scaleEffect(x: codeVisible ? 1 : .zero, anchor: .leading)
                }
                .accessibilityHidden(true)
        }
        .padding(Constants.padding)
        .background { surfaceBackground }
        .clipShape(RoundedRectangle(cornerRadius: Constants.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Constants.radius, style: .continuous)
                .strokeBorder(Color.primary.opacity(Constants.borderOpacity), lineWidth: Constants.borderWidth)
        }
        .opacity(surfaceVisible ? 1 : .zero)
        .scaleEffect(surfaceVisible ? 1 : Constants.surfaceStartScale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(BikeOnboardingL10n.text(.bikeOnboardingAccessibilityPairingCode(accessiblePIN)))
        .task(id: reduceMotion) { await reveal() }
    }

    @ViewBuilder private var surfaceBackground: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: Constants.radius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        } else {
            RoundedRectangle(cornerRadius: Constants.radius, style: .continuous)
                .fill(.thinMaterial)
        }
    }

    private var accessiblePIN: String {
        pin.map(String.init).joined(separator: " ")
    }

    @MainActor
    private func reveal() async {
        if reduceMotion {
            surfaceVisible = true
            codeVisible = true
            lockVisible = true
            return
        }

        surfaceVisible = false
        codeVisible = false
        lockVisible = false
        await Task.yield()
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: Constants.revealDuration)) {
            surfaceVisible = true
            codeVisible = true
        }
        withAnimation(.easeOut(duration: Constants.lockRevealDuration)) {
            lockVisible = true
        }
    }
}

private extension OnboardingPairingCodeView {
    enum Constants {
        static let contentSpacing: CGFloat = 18
        static let padding: CGFloat = 22
        static let radius: CGFloat = 22
        static let labelTracking: CGFloat = 1.8
        static let surfaceStartScale = 0.98
        static let lockStartScale = 0.8
        static let revealDuration = 0.25
        static let lockRevealDuration = 0.28
        static let borderOpacity = 0.08
        static let borderWidth: CGFloat = 1
    }
}
