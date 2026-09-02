import DesignSystem
import SwiftUI

struct BikeLockProtectionSelectionView: View {
    let options: [BikeLockProtectionOptionViewData]
    let errorMessage: String?
    let onSelect: (BikeLockProtectionOptionID) -> Void
    let onSaveNewPIN: (BikeLockProtectionOptionID, String, String) -> Void
    @AccessibilityFocusState private var isErrorFocused: Bool

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(DesignColor.critical)
                    .accessibilityLabel(
                        Text(.bikeLockSettingsErrorAccessibility(errorMessage))
                    )
                    .accessibilityFocused($isErrorFocused)
            }

            ForEach(options) { option in
                if option.requiresPINSetup {
                    NavigationLink {
                        BikeLockNewPINView(
                            title: .bikeLockSettingsCreatePINTitle,
                            errorMessage: errorMessage
                        ) { pin, confirmation in
                            onSaveNewPIN(option.id, pin, confirmation)
                        }
                    } label: {
                        row(for: option)
                    }
                } else {
                    Button { onSelect(option.id) } label: { row(for: option) }
                        .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(Text(.bikeLockSettingsUnlockProtectionTitle))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focusErrorIfNeeded(errorMessage) }
        .onChange(of: errorMessage) { _, newValue in focusErrorIfNeeded(newValue) }
    }

    private func row(for option: BikeLockProtectionOptionViewData) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                Text(option.title).foregroundStyle(DesignColor.primaryText)
                Text(option.detail)
                    .font(.footnote)
                    .foregroundStyle(DesignColor.secondaryText)
            }
            Spacer(minLength: DesignSpace.small)
            if option.isSelected { Image(systemName: "checkmark.circle.fill") }
        }
        .frame(maxWidth: .infinity, minHeight: Constants.minimumHeight, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func focusErrorIfNeeded(_ errorMessage: String?) {
        isErrorFocused = errorMessage != nil
    }

    private enum Constants {
        static let minimumHeight: CGFloat = 52
    }
}
