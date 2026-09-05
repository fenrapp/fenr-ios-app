import DesignSystem
import SwiftUI

struct PowerModeNameEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let mapIndex: Int
    let currentName: String
    let maximumLength: Int
    let isEnabled: Bool
    let error: String?
    let save: (String) -> Bool
    let reset: () -> Void
    @State private var draft: String
    @State private var isResetConfirmationPresented = false

    init(
        mapIndex: Int,
        currentName: String,
        maximumLength: Int,
        isEnabled: Bool,
        error: String?,
        save: @escaping (String) -> Bool,
        reset: @escaping () -> Void
    ) {
        self.mapIndex = mapIndex
        self.currentName = currentName
        self.maximumLength = maximumLength
        self.isEnabled = isEnabled
        self.error = error
        self.save = save
        self.reset = reset
        _draft = State(initialValue: currentName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: .powerModeSettingsMapNameField), text: $draft)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(submit)
                        .disabled(!isEnabled)
                        .accessibilityIdentifier("powerModes.name")

                    nameGuidance
                        .font(.caption)
                        .foregroundStyle(DesignColor.secondaryText)

                    if let error {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(DesignColor.critical)
                            .accessibilityLabel(Text(.powerModeSettingsErrorAccessibility(error)))
                    }
                }

                if !currentName.isEmpty {
                    Section {
                        Button(.powerModeSettingsResetName, role: .destructive) {
                            isResetConfirmationPresented = true
                        }
                        .frame(minHeight: Constants.minimumControlSize)
                    } footer: {
                        Text(.powerModeSettingsResetNameFooter)
                    }
                }
            }
            .navigationTitle(Text(.powerModeSettingsEditNameTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.powerModeSettingsCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(.powerModeSettingsSaveName, action: submit)
                        .disabled(!canSave)
                }
            }
            .confirmationDialog(
                Text(.powerModeSettingsResetNameConfirmationTitle),
                isPresented: $isResetConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(.powerModeSettingsResetName, role: .destructive) {
                    reset()
                    dismiss()
                }
                Button(.powerModeSettingsCancel, role: .cancel) {}
            } message: {
                Text(.powerModeSettingsResetNameConfirmationMessage)
            }
        }
        .onChange(of: mapIndex) {
            draft = currentName
        }
        .onChange(of: currentName) {
            draft = currentName
        }
    }

    @ViewBuilder
    private var nameGuidance: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(.powerModeSettingsNameGuidance)
                characterCount
            }
        } else {
            HStack {
                Text(.powerModeSettingsNameGuidance)
                Spacer()
                characterCount
            }
        }
    }

    private var characterCount: some View {
        Text(.powerModeSettingsCharacterCount(normalizedDraft.count, maximumLength))
            .foregroundStyle(
                normalizedDraft.count > maximumLength
                    ? DesignColor.critical
                    : DesignColor.secondaryText
            )
    }

    private var canSave: Bool {
        isEnabled
            && draft != currentName
            && !normalizedDraft.isEmpty
            && normalizedDraft.count <= maximumLength
    }

    private var normalizedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        guard canSave else { return }
        if save(draft) {
            dismiss()
        }
    }

    private enum Constants {
        static let minimumControlSize: CGFloat = 44
    }
}
