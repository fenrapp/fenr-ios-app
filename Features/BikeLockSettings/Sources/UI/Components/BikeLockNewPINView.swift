import DesignSystem
import SwiftUI

struct BikeLockNewPINView: View {
    let title: LocalizedStringResource
    let errorMessage: String?
    let onComplete: (String, String) -> Void
    @State private var pin = ""
    @State private var confirmation = ""
    @State private var isConfirming = false
    @AccessibilityFocusState private var isErrorFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: Constants.spacing) {
                Text(
                    isConfirming
                        ? .bikeLockSettingsEnterPINAgain
                        : .bikeLockSettingsChoosePIN
                )
                    .font(.headline)
                NumericPINPad(
                    pin: isConfirming ? $confirmation : $pin,
                    onComplete: complete
                )
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(DesignColor.critical)
                        .accessibilityLabel(
                            Text(.bikeLockSettingsErrorAccessibility(errorMessage))
                        )
                        .accessibilityFocused($isErrorFocused)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle(Text(title))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focusErrorIfNeeded(errorMessage) }
        .onChange(of: errorMessage) { _, newValue in focusErrorIfNeeded(newValue) }
    }

    private func complete(_ value: String) {
        if isConfirming {
            confirmation = ""
            onComplete(pin, value)
        } else {
            isConfirming = true
        }
    }

    private func focusErrorIfNeeded(_ errorMessage: String?) {
        isErrorFocused = errorMessage != nil
    }

    private enum Constants {
        static let spacing: CGFloat = 20
    }
}
