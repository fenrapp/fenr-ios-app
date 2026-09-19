import DesignSystem
import SwiftUI

struct OfflineSelectionControls: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: OfflineSelectionViewModel
    @FocusState private var editsName: Bool
    let onViewLibrary: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $model.name) { Text(.offlineAreaLabel) }
                        .focused($editsName).submitLabel(.done)
                        .onSubmit { editsName = false }
                } header: { Text(.offlineAreaLabel) }
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                            Text(.offlineTopographic).font(.body.weight(.medium))
                            Text(.offlineTopographicDetail).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "mountain.2.fill").foregroundStyle(DesignColor.accent) }
                    Toggle(isOn: Binding(get: { model.satellite }, set: { model.setSatellite($0) })) {
                        Label {
                            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                                Text(.offlineIncludeSatellite).font(.body.weight(.medium))
                                Text(.offlineSatelliteDetail).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "globe.europe.africa.fill").foregroundStyle(DesignColor.accent) }
                    }
                    if model.isRoute { marginPicker }
                } header: { Text(.offlineMapLayers) }
                Section {
                    Toggle(isOn: Binding(get: { model.wifiOnly }, set: { model.setWiFiOnly($0) })) {
                        Label(.offlineWiFiOnly, systemImage: "wifi")
                    }
                } footer: { Text(.offlineWiFiExplanation) }
                Section {
                    HStack {
                        Text(.offlineMapSize)
                        Spacer()
                        if model.isEstimating { ProgressView() } else { Text(verbatim: model.estimateText) }
                    }
                    .font(.subheadline)
                    if let transfer = model.transferText { Text(verbatim: transfer).font(.subheadline) }
                    Text(.offlineFreeSpace(model.freeText)).font(.subheadline).foregroundStyle(.secondary)
                    if let coverage = model.coverageText {
                        Label(coverage, systemImage: "checkmark.circle").font(.subheadline)
                        Button(.offlineViewLibrary, action: onViewLibrary)
                    }
                    if let error = model.errorText {
                        Label(error, systemImage: "exclamationmark.circle").foregroundStyle(DesignColor.critical)
                        Button(.offlineRetry, action: model.refreshEstimate)
                    }
                } header: { Text(.offlineDownloadSummary) }
            }
            .scrollDismissesKeyboard(.interactively)
            .tint(DesignColor.accent)
            .navigationTitle(.offlineDownloadOptions)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(.offlineBackToMap) { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(.offlineDone) { editsName = false }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !editsName { downloadButton }
            }
        }
    }

    private var marginPicker: some View {
        Picker(.offlineCorridorMargin, selection: Binding(
            get: { model.marginKilometers }, set: { model.setMargin($0) }
        )) {
            Text(.offlineMarginTwo).tag(2)
            Text(.offlineMarginFive).tag(5)
            Text(.offlineMarginTen).tag(10)
        }
    }

    private var downloadButton: some View {
        Button(action: model.download) {
            Label(.offlineDownload, systemImage: "arrow.down.circle.fill")
                .font(.body.weight(.semibold)).frame(maxWidth: .infinity)
                .padding(.vertical, DesignSpace.extraSmall)
        }
        .rideNavigationPrimaryButton()
        .buttonBorderShape(.capsule)
        .disabled(!model.canDownload || model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .padding(DesignSpace.medium)
        .background(.bar)
    }
}
