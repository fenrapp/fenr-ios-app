import DesignSystem
import SwiftUI

struct PowerModeNameEditor: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let mapIndex: Int
    let currentName: String
    let maximumLength: Int
    let isEnabled: Bool
    let error: String?
    let save: (String) -> Void
    let reset: () -> Void
    @State private var draft: String

    init(
        mapIndex: Int,
        currentName: String,
        maximumLength: Int,
        isEnabled: Bool,
        error: String?,
        save: @escaping (String) -> Void,
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
        VStack(alignment: .leading, spacing: Constants.spacing) {
            TextField(String(localized: .powerModeSettingsMapNameField), text: $draft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(submit)
                .disabled(!isEnabled)

            nameGuidance
            .font(.caption)
            .foregroundStyle(DesignColor.secondaryText)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(DesignColor.critical)
                    .accessibilityLabel(Text(.powerModeSettingsErrorAccessibility(error)))
            }

            nameActions
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
        Text(.powerModeSettingsCharacterCount(draft.count, maximumLength))
            .foregroundStyle(
                draft.count > maximumLength
                    ? DesignColor.critical
                    : DesignColor.secondaryText
            )
    }

    @ViewBuilder
    private var nameActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                saveButton
                resetButton
            }
        } else {
            HStack {
                saveButton
                resetButton
            }
        }
    }

    private var saveButton: some View {
        Button(.powerModeSettingsSaveName, action: submit)
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
    }

    @ViewBuilder
    private var resetButton: some View {
        if !currentName.isEmpty {
            Button(.powerModeSettingsResetName, role: .destructive, action: reset)
                .buttonStyle(.bordered)
        }
    }

    private var canSave: Bool {
        isEnabled && draft != currentName && !draft.isEmpty
    }

    private func submit() {
        guard canSave else { return }
        save(draft)
    }

    private enum Constants {
        static let spacing = DesignSpace.extraSmall
    }
}
