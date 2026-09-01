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
                Section { Text(error).foregroundStyle(DesignColor.critical) }
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
        Section("Unlock protection") {
            LabeledContent("Current mode", value: viewState.currentModeTitle)
            Button("Change protection", action: onChangeProtection)
            if viewState.canChangePIN {
                Button("Change PIN", action: onChangePIN)
            }
        }

        explanationSection
    }

    @ViewBuilder
    private var unavailableContent: some View {
        Section {
            ContentUnavailableView(
                "Bike Lock Unavailable",
                systemImage: "lock.slash",
                description: Text("Connect a compatible motorcycle to configure unlock protection.")
            )
        }

        explanationSection
    }

    private var explanationSection: some View {
        Section {
            Text("These settings protect unlocking in FENR. They do not lock or unlock the motorcycle.")
                .foregroundStyle(DesignColor.secondaryText)
        }
    }
}
