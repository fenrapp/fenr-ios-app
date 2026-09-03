import DesignSystem
import SwiftUI

struct BikeLockSettingsContent: View {
    let viewState: BikeLockSettingsViewState
    let onChangeProtection: () -> Void
    let onChangePIN: () -> Void

    var body: some View {
        Form {
            if viewState.isAvailable {
                availableContent
            } else {
                unavailableContent
            }

            if let error = viewState.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(DesignColor.critical)
                        .accessibilityLabel(
                            Text(.bikeLockSettingsErrorAccessibility(error))
                        )
                }
            }
        }
        .disabled(viewState.isWorking)
        .overlay {
            if viewState.isWorking {
                ProgressView()
                    .controlSize(.large)
            }
        }
    }

    @ViewBuilder
    private var availableContent: some View {
        Section(.bikeLockSettingsUnlockProtectionSection) {
            LabeledContent(
                String(localized: .bikeLockSettingsCurrentMode),
                value: viewState.currentModeTitle
            )
            Button(.bikeLockSettingsChangeProtection, action: onChangeProtection)
            if viewState.canChangePIN {
                Button(.bikeLockSettingsChangePIN, action: onChangePIN)
            }
        }

    }

    @ViewBuilder
    private var unavailableContent: some View {
        Section {
            ContentUnavailableView(
                .bikeLockSettingsUnavailableTitle,
                systemImage: "lock.slash",
                description: Text(.bikeLockSettingsUnavailableDescription)
            )
        }

    }
}
