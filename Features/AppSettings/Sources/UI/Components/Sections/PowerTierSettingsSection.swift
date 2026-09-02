#if os(iOS)
import DesignSystem
import SwiftUI

struct PowerTierSettingsSection: View {
    let state: PowerTierSettingsViewState
    let onSelectDeclaredTier: (String) -> Void
    let onVerify: () -> Void

    var body: some View {
        Section {
            Picker(.appSettingsDeclaredModelPickerTitle, selection: selectionBinding) {
                ForEach(state.selection.options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent {
                Text(state.status)
            } label: {
                Text(.appSettingsDetectedStatusLabel)
            }

            if let evidence = state.evidence {
                LabeledContent {
                    Text(evidence)
                } label: {
                    Text(.appSettingsEvidenceLabel)
                }
            }
            if let verificationMessage = state.verificationMessage {
                Text(verificationMessage)
                    .font(.footnote)
                    .foregroundStyle(
                        state.verificationMessageIsError
                            ? DesignColor.critical
                            : DesignColor.positive
                    )
            }
            Button(action: onVerify) {
                if state.isVerifying {
                    ProgressView()
                } else {
                    Text(.appSettingsVerifyWithBikeButton)
                }
            }
            .disabled(!state.isVerifyEnabled)

        } header: {
            Text(.appSettingsModelCapabilityHeader)
        } footer: {
            Text(.appSettingsModelCapabilityFooter)
        }
    }

    private var selectionBinding: Binding<String> {
        .init(
            get: { state.selection.selectedID },
            set: { onSelectDeclaredTier($0) }
        )
    }
}
#endif
