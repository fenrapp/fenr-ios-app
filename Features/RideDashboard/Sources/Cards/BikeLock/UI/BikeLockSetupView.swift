import SwiftUI

struct BikeLockSetupView: View {
    let options: [BikeLockSecurityOptionViewData]
    let configure: (String, String) -> Void
    let cancel: () -> Void

    @State private var selectedOptionID = "pinAndFaceID"
    @State private var pin = ""
    @State private var pinEntry = ""
    @State private var isShowingPINSetup = false
    @State private var pinPhase = PINPhase.create
    @State private var pinError: String?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        NavigationStack {
            protectionOptions
                .navigationTitle("Set Up Bike Lock")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: cancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        protectionConfirmationButton
                    }
                }
                .navigationDestination(isPresented: $isShowingPINSetup) {
                    pinSetup
                        .navigationTitle("Create Unlock PIN")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Enable", action: enableSelectedMode)
                                    .disabled(pinPhase != .confirmed)
                            }
                        }
                        .navigationBarBackButtonHidden(false)
                }
        }
    }

    private var protectionOptions: some View {
        Form {
            Section("Unlock protection") {
                ForEach(options) { option in
                    Button {
                        select(option)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: Constants.optionSpacing) {
                                Text(option.title)
                                Text(option.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedOptionID == option.id {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var pinSetup: some View {
        ScrollView {
            Group {
                if verticalSizeClass == .compact {
                    HStack(spacing: Constants.compactColumnSpacing) {
                        pinGuidance
                            .frame(maxWidth: .infinity)
                        pinControl
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: Constants.pinContentSpacing) {
                        pinGuidance
                        pinControl
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Constants.pinContentPadding)
        }
    }

    private var pinGuidance: some View {
        VStack(spacing: Constants.pinTextSpacing) {
            Text(pinPhase.title)
                .font(.headline)
            Text(pinPhase.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let pinError {
                Text(pinError)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var pinControl: some View {
        if pinPhase == .confirmed {
            VStack(spacing: Constants.pinContentSpacing) {
                Label("PIN confirmed", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding(.vertical, Constants.confirmedPadding)

                Button("Enter PIN Again", action: resetPIN)
                    .buttonStyle(.bordered)
            }
        } else {
            BikeLockPINPad(pin: $pinEntry, onComplete: completePINEntry)
        }
    }

    @ViewBuilder
    private var protectionConfirmationButton: some View {
        if selectedOption?.requiresPIN == true {
            Button("Continue") {
                resetPIN()
                isShowingPINSetup = true
            }
        } else {
            Button("Enable", action: enableSelectedMode)
        }
    }

    private var selectedOption: BikeLockSecurityOptionViewData? {
        options.first(where: { $0.id == selectedOptionID })
    }

    private func select(_ option: BikeLockSecurityOptionViewData) {
        guard selectedOptionID != option.id else { return }
        selectedOptionID = option.id
        resetPIN()
    }

    private func completePINEntry(_ value: String) {
        switch pinPhase {
        case .create:
            pin = value
            pinEntry = ""
            pinPhase = .confirm
            pinError = nil
        case .confirm:
            guard value == pin else {
                pinEntry = ""
                pinError = "PINs did not match. Try the confirmation again."
                return
            }
            pinPhase = .confirmed
            pinError = nil
        case .confirmed:
            break
        }
    }

    private func enableSelectedMode() {
        configure(selectedOptionID, pin)
    }

    private func resetPIN() {
        pin = ""
        pinEntry = ""
        pinPhase = .create
        pinError = nil
    }

    private enum Constants {
        static let optionSpacing: CGFloat = 3
        static let pinContentSpacing: CGFloat = 18
        static let pinTextSpacing: CGFloat = 4
        static let pinContentPadding: CGFloat = 20
        static let confirmedPadding: CGFloat = 24
        static let compactColumnSpacing: CGFloat = 28
    }

    private enum PINPhase {
        case create
        case confirm
        case confirmed

        var title: String {
            switch self {
            case .create: "Enter a 6-digit PIN"
            case .confirm: "Confirm your PIN"
            case .confirmed: "PIN ready"
            }
        }

        var detail: String {
            switch self {
            case .create: "Use the keypad below."
            case .confirm: "Enter the same six digits again."
            case .confirmed: "Your PIN is ready to enable."
            }
        }
    }
}
