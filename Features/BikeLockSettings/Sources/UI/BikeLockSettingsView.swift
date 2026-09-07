import SwiftUI

public struct BikeLockSettingsView: View {
    private let viewModel: BikeLockSettingsViewModel

    public init(viewModel: BikeLockSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        BikeLockSettingsContent(
            viewState: viewModel.viewState,
            onChangeProtection: viewModel.changeProtection,
            onChangePIN: viewModel.changePIN
        )
        .navigationTitle(Text(.bikeLockSettingsTitle))
        .navigationBarTitleDisplayMode(.inline)
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
            BikeLockPINInputView(
                title: .bikeLockSettingsEnterCurrentPINTitle,
                errorMessage: viewModel.viewState.errorMessage
            ) { pin in
                viewModel.submitCurrentPIN(pin)
            }
        case .chooseProtection:
            BikeLockProtectionSelectionView(
                options: viewModel.viewState.protectionOptions,
                errorMessage: viewModel.viewState.errorMessage,
                onSelect: viewModel.select,
                onSaveNewPIN: { optionID, pin, confirmation in
                    viewModel.saveNewPIN(pin, confirmation: confirmation, optionID: optionID)
                }
            )
        case .changePIN:
            BikeLockNewPINView(
                title: .bikeLockSettingsChangePIN,
                errorMessage: viewModel.viewState.errorMessage
            ) { pin, confirmation in
                viewModel.saveNewPIN(pin, confirmation: confirmation)
            }
        case nil:
            EmptyView()
        }
    }
}
