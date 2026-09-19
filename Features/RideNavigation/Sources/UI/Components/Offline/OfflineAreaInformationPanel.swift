import DesignSystem
import SwiftUI

struct OfflineAreaInformationPanel: View {
    let area: OfflineAreaRow
    let error: String?
    let busy: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onExplore: () -> Void

    var body: some View {
        VStack(spacing: .zero) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSpace.medium) {
                    Label(area.status, systemImage: area.symbol)
                        .font(.title3.weight(.bold))
                    Text(verbatim: area.explanation).font(.subheadline).foregroundStyle(.secondary)
                    if let progress = area.progress {
                        VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                            ProgressView(value: progress)
                            Text(verbatim: area.progressText).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    VStack(spacing: DesignSpace.small) {
                        ForEach(area.layerRows) { layer in
                            HStack(spacing: DesignSpace.small) {
                                Image(systemName: layer.symbol).foregroundStyle(DesignColor.accent)
                                Text(verbatim: layer.title).font(.subheadline.weight(.medium))
                                Spacer()
                                Text(verbatim: layer.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                        HStack(alignment: .firstTextBaseline) {
                            Text(.offlineMapSize).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(verbatim: area.size).font(.subheadline.weight(.semibold))
                        }
                        Text(.offlineLastUpdated(area.updated)).font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let reminder = area.reminder {
                        Label(reminder, systemImage: "arrow.clockwise").font(.caption).foregroundStyle(.secondary)
                    }
                    if let error {
                        Label(error, systemImage: "exclamationmark.circle").font(.subheadline)
                            .foregroundStyle(DesignColor.critical)
                    }
                }
                .padding(DesignSpace.medium)
            }
            action.padding([.horizontal, .bottom], DesignSpace.medium)
        }
    }

    private var action: some View {
        Button(action: area.canPause ? onPause : area.canResume ? onResume : onExplore) {
            Label(
                area.canPause ? .offlinePause : area.canResume ? .offlineResume : .offlineExploreMap,
                systemImage: area.canPause ? "pause.fill" : area.canResume ? "arrow.down" : "map"
            )
            .font(.body.weight(.semibold)).frame(maxWidth: .infinity)
            .padding(.vertical, DesignSpace.extraSmall)
        }
        .rideNavigationPrimaryButton()
        .buttonBorderShape(.capsule)
        .disabled(busy)
    }
}
