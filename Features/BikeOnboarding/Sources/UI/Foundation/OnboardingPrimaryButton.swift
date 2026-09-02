import SwiftUI

struct OnboardingPrimaryButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    var systemImage: String?
    var accessibilityLabel: String?
    var isBusy = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isBusy {
                    ProgressView()
                        .tint(contentColor)
                } else {
                    Text(title)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(
                            .vertical,
                            dynamicTypeSize.isAccessibilitySize ? Constants.accessibilityPadding : .zero
                        )
                    if let systemImage, !dynamicTypeSize.isAccessibilitySize {
                        HStack {
                            Spacer()
                            Image(systemName: systemImage)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.trailing, Constants.iconTrailingPadding)
                    }
                }
            }
            .font(buttonFont)
            .frame(maxWidth: .infinity, minHeight: Constants.height)
            .contentShape(Capsule())
        }
        .disabled(isDisabled || isBusy)
        .buttonStyle(.plain)
        .foregroundStyle(contentColor)
        .background(backgroundColor, in: Capsule())
        .opacity(isDisabled ? Constants.disabledOpacity : 1)
        .shadow(
            color: .black.opacity(Constants.shadowOpacity),
            radius: Constants.shadowRadius,
            y: Constants.shadowOffset
        )
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityValue(isBusy ? BikeOnboardingL10n.text(.bikeOnboardingAccessibilityInProgress) : "")
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var contentColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var buttonFont: Font {
        dynamicTypeSize.isAccessibilitySize ? .body.weight(.semibold) : .headline
    }
}

private extension OnboardingPrimaryButton {
    enum Constants {
        static let height: CGFloat = 58
        static let accessibilityPadding: CGFloat = 12
        static let iconTrailingPadding: CGFloat = 22
        static let disabledOpacity = 0.45
        static let shadowOpacity = 0.28
        static let shadowRadius: CGFloat = 18
        static let shadowOffset: CGFloat = 8
    }
}
