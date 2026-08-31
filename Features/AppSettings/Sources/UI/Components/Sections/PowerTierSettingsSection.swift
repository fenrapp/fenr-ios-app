#if os(iOS)
import SwiftUI

struct PowerTierSettingsSection: View {
    let state: PowerTierSettingsViewState
    let onSelectDeclaredTier: (String) -> Void
    let onVerify: () -> Void

    var body: some View {
        Section("Bike power tier") {
            Picker("Declared model", selection: selectionBinding) {
                ForEach(state.selection.options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.segmented)

            Text(state.status)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let evidence = state.evidence {
                Text(evidence)
                    .font(.footnote)
            }
            if let verificationMessage = state.verificationMessage {
                Text(verificationMessage)
                    .font(.footnote)
            }
            Button(action: onVerify) {
                if state.isVerifying {
                    ProgressView()
                } else {
                    Text("Verify with bike")
                }
            }
            .disabled(!state.isVerifyEnabled)

            Text(
                "The manual selection is only an expectation. "
                    + "Bike telemetry determines HP, TC and the effective tier."
            )
                .font(.caption)
                .foregroundStyle(.secondary)
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
