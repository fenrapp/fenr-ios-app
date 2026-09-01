import DesignSystem
import SwiftUI

struct BikeLockPINInputView: View {
    let title: String
    let errorMessage: String?
    let onComplete: (String) -> Void
    @State private var pin = ""
    @AccessibilityFocusState private var isErrorFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: Constants.spacing) {
                NumericPINPad(pin: $pin, onComplete: complete)
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(DesignColor.critical)
                        .accessibilityLabel("Error: \(errorMessage)")
                        .accessibilityFocused($isErrorFocused)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focusErrorIfNeeded(errorMessage) }
        .onChange(of: errorMessage) { _, newValue in focusErrorIfNeeded(newValue) }
    }

    private func complete(_ value: String) {
        pin = ""
        onComplete(value)
    }

    private func focusErrorIfNeeded(_ errorMessage: String?) {
        isErrorFocused = errorMessage != nil
    }

    private enum Constants {
        static let spacing = DesignSpace.small
    }
}
