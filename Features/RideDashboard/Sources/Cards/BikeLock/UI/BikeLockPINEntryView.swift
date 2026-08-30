import SwiftUI

struct BikeLockPINEntryView: View {
    let title: String
    let submit: (String) -> Void
    let cancel: () -> Void

    @State private var pin = ""

    var body: some View {
        NavigationStack {
            BikeLockPINPad(pin: $pin, onComplete: submit)
            .padding(Constants.contentPadding)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
            }
        }
    }

    private enum Constants {
        static let contentPadding: CGFloat = 24
    }
}
