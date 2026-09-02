import SwiftUI

struct OnboardingBluetoothRecoveryGuide: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let steps: [Step]

    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.rowSpacing) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                guideRow(step, at: index)
                    .opacity(isVisible ? 1 : .zero)
                    .offset(y: isVisible ? .zero : Constants.rowEntranceOffset)
                    .animation(rowAnimation(index: index), value: isVisible)
            }
        }
        .task(id: reduceMotion) {
            isVisible = reduceMotion
            guard !reduceMotion else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            isVisible = true
        }
    }

    private func guideRow(_ step: Step, at index: Int) -> some View {
        HStack(alignment: .top, spacing: Constants.contentSpacing) {
            Text(String(format: "%02d", index + 1))
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: Constants.numberWidth, alignment: .leading)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Constants.textSpacing) {
                Text(step.title)
                    .font(.headline)
                Text(step.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: .zero)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            BikeOnboardingL10n.stepAccessibility(
                index: index + 1,
                count: steps.count,
                title: step.title,
                detail: step.detail
            )
        )
    }

    private func rowAnimation(index: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return .easeOut(duration: Constants.revealDuration)
            .delay(Double(index) * Constants.rowDelay)
    }
}

extension OnboardingBluetoothRecoveryGuide {
    struct Step {
        let title: String
        let detail: String
    }
}

private extension OnboardingBluetoothRecoveryGuide {
    enum Constants {
        static let rowSpacing: CGFloat = 22
        static let contentSpacing: CGFloat = 14
        static let textSpacing: CGFloat = 3
        static let numberWidth: CGFloat = 28
        static let rowEntranceOffset: CGFloat = 6
        static let revealDuration = 0.22
        static let rowDelay = 0.05
    }
}
