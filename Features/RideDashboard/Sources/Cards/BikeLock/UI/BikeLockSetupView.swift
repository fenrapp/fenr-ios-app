import DesignSystem
import SwiftUI

struct BikeLockSetupView: View {
    let options: [BikeLockSecurityOptionViewData]
    let errorText: String?
    let isWorking: Bool
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
                .navigationTitle(.rideDashboardBikeLockSetupTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(.rideDashboardCommonCancel, action: cancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        protectionConfirmationButton
                    }
                }
                .navigationDestination(isPresented: $isShowingPINSetup) {
                    pinSetup
                        .navigationTitle(.rideDashboardBikeLockSetupCreatePINTitle)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(.rideDashboardCommonEnable, action: enableSelectedMode)
                                    .disabled(pinPhase != .confirmed)
                            }
                        }
                        .navigationBarBackButtonHidden(false)
                }
        }
        .disabled(isWorking)
        .interactiveDismissDisabled(isWorking)
    }

    private var protectionOptions: some View {
        Form {
            if let errorText {
                Text(verbatim: errorText)
                    .foregroundStyle(DesignColor.critical)
                    .accessibilityIdentifier("bikeLock.setup.error")
            }
            Section(.rideDashboardBikeLockSetupSectionProtection) {
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
                    .accessibilityIdentifier("bikeLock.setup.option.\(option.id)")
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

            if let error = pinError ?? errorText {
                Text(verbatim: error)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("bikeLock.setup.error")
            }
        }
    }

    @ViewBuilder
    private var pinControl: some View {
        if pinPhase == .confirmed {
            VStack(spacing: Constants.pinContentSpacing) {
                Label(.rideDashboardBikeLockSetupPinConfirmed, systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding(.vertical, Constants.confirmedPadding)

                Button(.rideDashboardBikeLockSetupEnterPINAgain, action: resetPIN)
                    .buttonStyle(.bordered)
            }
        } else {
            NumericPINPad(pin: $pinEntry, onComplete: completePINEntry)
        }
    }

    @ViewBuilder
    private var protectionConfirmationButton: some View {
        if selectedOption?.requiresPIN == true {
            Button(.rideDashboardBikeLockSetupContinue) {
                resetPIN()
                isShowingPINSetup = true
            }
        } else {
            Button(.rideDashboardCommonEnable, action: enableSelectedMode)
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
                pinError = rideDashboardLocalized(.rideDashboardBikeLockSetupPinMismatch)
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
            case .create: rideDashboardLocalized(.rideDashboardBikeLockSetupPhaseCreateTitle)
            case .confirm: rideDashboardLocalized(.rideDashboardBikeLockSetupPhaseConfirmTitle)
            case .confirmed: rideDashboardLocalized(.rideDashboardBikeLockSetupPhaseConfirmedTitle)
            }
        }

        var detail: String {
            switch self {
            case .create: rideDashboardLocalized(.rideDashboardBikeLockSetupPhaseCreateDetail)
            case .confirm: rideDashboardLocalized(.rideDashboardBikeLockSetupPhaseConfirmDetail)
            case .confirmed: rideDashboardLocalized(.rideDashboardBikeLockSetupPhaseConfirmedDetail)
            }
        }
    }
}
