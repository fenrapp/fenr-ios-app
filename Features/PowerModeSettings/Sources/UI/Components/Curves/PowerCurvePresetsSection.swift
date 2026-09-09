import DesignSystem
import SwiftUI

struct PowerCurvePresetsSection: View {
    let state: PowerModeAdvancedViewState
    let send: (PowerModeAdvancedIntent) -> Void
    @State private var isEditingName = false
    @State private var presetName = ""
    @State private var renamingID: UUID?

    var body: some View {
        Section {
            if state.presets.isEmpty {
                Text(.powerCurvePresetsEmpty)
                    .font(.subheadline)
                    .foregroundStyle(DesignColor.secondaryText)
            }
            ForEach(state.presets) { preset in
                HStack(spacing: DesignSpace.small) {
                    Button { send(.loadPreset(preset.id)) } label: {
                        HStack(spacing: DesignSpace.small) {
                            Image(systemName: "chart.xyaxis.line")
                                .foregroundStyle(DesignColor.accent)
                                .padding(DesignSpace.extraSmall)
                                .background(DesignColor.groupedSurface, in: RoundedRectangle(
                                    cornerRadius: DesignRadius.small
                                ))
                            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                                Text(verbatim: preset.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(DesignColor.primaryText)
                                Text(preset.isCompatible ? .powerCurvePresetLoadHint : .powerCurvePresetIncompatible)
                                    .font(.caption)
                                    .foregroundStyle(DesignColor.secondaryText)
                            }
                            Spacer(minLength: DesignSpace.extraSmall)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!preset.isCompatible || !state.canEdit)
                    Menu {
                        Button(.powerCurveRenamePreset) {
                            renamingID = preset.id
                            presetName = preset.name
                            isEditingName = true
                        }
                        Button(.powerCurveDuplicate) { send(.duplicatePreset(preset.id)) }
                        Button(.powerCurveDelete, role: .destructive) { send(.deletePreset(preset.id)) }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .disabled(state.isBusy)
                    .accessibilityLabel(.powerCurvePresetActions)
                }
                .padding(.vertical, DesignSpace.extraExtraSmall)
            }
        } header: {
            HStack {
                Text(.powerCurvePresets)
                Spacer()
                Button {
                    renamingID = nil
                    presetName = ""
                    isEditingName = true
                } label: {
                    Label(.powerCurveSavePreset, systemImage: "plus")
                }
                .font(.caption.weight(.semibold))
                .disabled(!state.canSavePreset)
            }
            .textCase(nil)
        } footer: {
            Text(.powerCurvePresetsFooter)
        }
        .alert(renamingID == nil ? .powerCurveSavePreset : .powerCurveRenamePreset, isPresented: $isEditingName) {
            TextField(String(localized: .powerCurvePresetName), text: $presetName)
            Button(.powerCurveSave) {
                if let renamingID {
                    send(.renamePreset(id: renamingID, name: presetName))
                } else {
                    send(.savePreset(presetName))
                }
            }
            .disabled(!isValidName)
            Button(.powerCurveCancel, role: .cancel) {}
        }
    }

    private var isValidName: Bool {
        let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= PowerModePresetViewData.maximumNameLength
    }
}
