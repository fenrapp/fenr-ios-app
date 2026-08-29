import SwiftUI

struct BikeLockSetupView: View {
    let options: [BikeLockSecurityOptionViewData]
    let configure: (String, String) -> Void
    let cancel: () -> Void

    @State private var selectedOptionID = "pinAndFaceID"
    @State private var pin = ""
    @State private var confirmation = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Unlock protection") {
                    ForEach(options) { option in
                        Button {
                            selectedOptionID = option.id
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
                        }
                        .buttonStyle(.plain)
                    }
                }

                if selectedOption?.requiresPIN == true {
                    Section("6-digit PIN") {
                        SecureField("PIN", text: pinBinding)
                            .keyboardType(.numberPad)
                        SecureField("Confirm PIN", text: confirmationBinding)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Set Up Bike Lock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enable") {
                        configure(selectedOptionID, pin)
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }

    private var selectedOption: BikeLockSecurityOptionViewData? {
        options.first(where: { $0.id == selectedOptionID })
    }

    private var canSubmit: Bool {
        guard selectedOption?.requiresPIN == true else { return true }
        return pin.count == 6 && pin == confirmation
    }

    private var pinBinding: Binding<String> {
        .init(get: { pin }, set: { pin = String($0.filter(\.isNumber).prefix(6)) })
    }

    private var confirmationBinding: Binding<String> {
        .init(get: { confirmation }, set: { confirmation = String($0.filter(\.isNumber).prefix(6)) })
    }

    private enum Constants {
        static let optionSpacing: CGFloat = 3
    }
}
