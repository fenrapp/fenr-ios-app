import DesignSystem
import SettingsDomain
import SwiftUI

public struct BikeLockSettingsView: View {
    @ObservedObject private var viewModel: BikeLockSettingsViewModel

    public init(viewModel: BikeLockSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section("Unlock protection") {
                LabeledContent("Current mode", value: viewModel.viewState.currentModeTitle)
                Button("Change protection", action: viewModel.changeProtection)
                if viewModel.viewState.canChangePIN {
                    Button("Change PIN", action: viewModel.changePIN)
                }
            }

            Section {
                Text("These settings protect unlocking in FENR. They do not lock or unlock the motorcycle.")
                    .foregroundStyle(.secondary)
            }

            if let error = viewModel.viewState.errorMessage {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Bike Lock")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(viewModel.viewState.isWorking)
        .overlay { if viewModel.viewState.isWorking { ProgressView() } }
        .navigationDestination(
            isPresented: Binding(
                get: { viewModel.viewState.destination != nil },
                set: { if !$0 { viewModel.dismissDestination() } }
            )
        ) {
            destinationView
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch viewModel.viewState.destination {
        case .verifyCurrentPIN:
            BikeLockPINInputView(title: "Enter Current PIN") { pin in
                viewModel.submitCurrentPIN(pin)
            }
        case .chooseProtection:
            BikeLockProtectionSelectionView(
                selection: viewModel.viewState.currentMode,
                onSelect: viewModel.select,
                onSaveNewPIN: { mode, pin, confirmation in
                    viewModel.saveNewPIN(pin, confirmation: confirmation, mode: mode)
                }
            )
        case .createPIN(let mode):
            BikeLockNewPINView(title: "Create PIN") { pin, confirmation in
                viewModel.saveNewPIN(pin, confirmation: confirmation, mode: mode)
            }
        case .changePIN:
            BikeLockNewPINView(title: "Change PIN") { pin, confirmation in
                viewModel.saveNewPIN(pin, confirmation: confirmation)
            }
        case nil:
            EmptyView()
        }
    }
}
