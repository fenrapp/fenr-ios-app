import DesignSystem
import SwiftUI

struct BikeLockPINInputView: View {
    let title: String
    let onComplete: (String) -> Void
    @State private var pin = ""

    var body: some View {
        ScrollView {
            NumericPINPad(pin: $pin, onComplete: onComplete)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
