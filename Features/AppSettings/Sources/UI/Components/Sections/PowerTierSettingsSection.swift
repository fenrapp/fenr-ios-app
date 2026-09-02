#if os(iOS)
import DesignSystem
import SwiftUI

struct PowerTierSettingsSection: View {
    let state: PowerTierSettingsViewState
    let onSelectDeclaredTier: (String) -> Void
    let onVerify: () -> Void

    var body: some View {
        Section {
            Picker("Declared Model", selection: selectionBinding) {
                ForEach(state.selection.options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent("Detected Status", value: state.status)

            if let evidence = state.evidence {
                LabeledContent("Evidence", value: evidence)
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
                    Text("Verify with bike")
                }
            }
            .disabled(!state.isVerifyEnabled)

        } header: {
            Text("Model and Capability")
        } footer: {
            Text(
                "The manual selection is only an expectation. "
                    + "Bike telemetry determines HP, TC and the effective tier."
            )
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
