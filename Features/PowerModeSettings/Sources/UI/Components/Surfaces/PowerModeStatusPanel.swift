import SwiftUI

struct PowerModeStatusPanel: View {
    let connectionText: String
    let capabilityText: String
    let statusText: String
    let statusIsError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            Label(connectionText, systemImage: "motorcycle")
            Label(capabilityText, systemImage: "bolt.fill")
            Label(statusText, systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.shield")
                .foregroundStyle(statusIsError ? Color.red : Color.secondary)
        }
        .font(.footnote)
    }

    private enum Constants {
        static let spacing: CGFloat = 7
    }
}
