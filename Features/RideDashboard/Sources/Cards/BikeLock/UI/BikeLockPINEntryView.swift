import DesignSystem
import SwiftUI

struct BikeLockPINEntryView: View {
    let title: String
    let errorText: String?
    let isWorking: Bool
    let submit: (String) -> Void
    let cancel: () -> Void

    @State private var pin = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSpace.medium) {
                    if let errorText {
                        Text(verbatim: errorText)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(DesignColor.critical)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("bikeLock.pin.error")
                    }
                    NumericPINPad(pin: $pin) { value in
                        pin = ""
                        submit(value)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(Constants.contentPadding)
            }
            .disabled(isWorking)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.rideDashboardCommonCancel, action: cancel)
                        .disabled(isWorking)
                }
            }
        }
        .interactiveDismissDisabled(isWorking)
    }

    private enum Constants {
        static let contentPadding: CGFloat = 24
    }
}
