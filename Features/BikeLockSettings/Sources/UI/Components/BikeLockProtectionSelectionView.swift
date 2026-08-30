import SettingsDomain
import SwiftUI

struct BikeLockProtectionSelectionView: View {
    let selection: BikeLockSecurityMode
    let onSelect: (BikeLockSecurityMode) -> Void
    let onSaveNewPIN: (BikeLockSecurityMode, String, String) -> Void

    var body: some View {
        List(options, id: \.self) { mode in
            if mode.requiresPIN, !selection.requiresPIN {
                NavigationLink {
                    BikeLockNewPINView(title: "Create PIN") { pin, confirmation in
                        onSaveNewPIN(mode, pin, confirmation)
                    }
                } label: {
                    row(for: mode)
                }
            } else {
                Button { onSelect(mode) } label: { row(for: mode) }
                    .buttonStyle(.plain)
            }
        }
        .navigationTitle("Unlock Protection")
        .navigationBarTitleDisplayMode(.inline)
    }

    private let options: [BikeLockSecurityMode] = [.pinAndFaceID, .pin, .withoutPIN]

    private func row(for mode: BikeLockSecurityMode) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Constants.spacing) {
                Text(mode.title).foregroundStyle(.primary)
                Text(mode.detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if mode == selection { Image(systemName: "checkmark.circle.fill") }
        }
        .frame(maxWidth: .infinity, minHeight: Constants.minimumHeight, alignment: .leading)
        .contentShape(Rectangle())
    }

    private enum Constants {
        static let spacing: CGFloat = 4
        static let minimumHeight: CGFloat = 52
    }
}

private extension BikeLockSecurityMode {
    var detail: String {
        switch self {
        case .pinAndFaceID: "Use Face ID first, with your PIN as a fallback."
        case .pin: "Enter a 6-digit PIN whenever you unlock."
        case .withoutPIN: "Lock and unlock immediately from the card."
        case .notConfigured: ""
        }
    }
}
