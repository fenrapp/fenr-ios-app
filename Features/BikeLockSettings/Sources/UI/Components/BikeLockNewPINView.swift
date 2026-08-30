import DesignSystem
import SwiftUI

struct BikeLockNewPINView: View {
    let title: String
    let onComplete: (String, String) -> Void
    @State private var pin = ""
    @State private var confirmation = ""
    @State private var isConfirming = false

    var body: some View {
        ScrollView {
            VStack(spacing: Constants.spacing) {
                Text(isConfirming ? "Enter the PIN again" : "Choose a 6-digit PIN")
                    .font(.headline)
                NumericPINPad(
                    pin: isConfirming ? $confirmation : $pin,
                    onComplete: complete
                )
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func complete(_ value: String) {
        if isConfirming {
            onComplete(pin, value)
        } else {
            isConfirming = true
        }
    }

    private enum Constants {
        static let spacing: CGFloat = 20
    }
}
