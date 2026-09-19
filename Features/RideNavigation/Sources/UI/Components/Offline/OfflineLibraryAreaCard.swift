import DesignSystem
import SwiftUI

struct OfflineLibraryAreaCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let area: OfflineAreaRow
    let thumbnail: AnyView
    let onOpen: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void

    var body: some View {
        HStack(spacing: DesignSpace.extraSmall) {
            content
            Button(action: onOpen) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    .frame(width: Constants.accessorySize, height: Constants.accessorySize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: area.name))
        }
        .padding(DesignSpace.medium)
        .rideNavigationGlassSurface(cornerRadius: Constants.radius)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignSpace.small) {
            Button(action: onOpen) {
                headerLayout {
                    thumbnail
                        .frame(width: Constants.thumbnailWidth, height: Constants.thumbnailHeight)
                        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.small))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                        Text(verbatim: area.name).font(.headline).foregroundStyle(.primary)
                        Text(verbatim: area.layers).font(.caption).foregroundStyle(.secondary)
                        Text(verbatim: area.size).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: DesignSpace.extraSmall)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let progress = area.progress {
                ProgressView(value: progress).tint(DesignColor.accent)
                Text(verbatim: area.progressText).font(.caption).foregroundStyle(.secondary)
            }
            if area.canPause || area.canResume {
                Text(verbatim: area.explanation).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Label(area.status, systemImage: area.symbol).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: DesignSpace.extraSmall)
                if area.canPause {
                    Button(action: onPause) { Image(systemName: "pause.fill") }
                        .accessibilityLabel(.offlinePause)
                        .rideNavigationSecondaryButton()
                } else if area.canResume {
                    Button(action: onResume) { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel(.offlineResume)
                        .rideNavigationSecondaryButton()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignSpace.small))
            : AnyLayout(HStackLayout(spacing: DesignSpace.medium))
    }

    private enum Constants {
        static let thumbnailWidth = 100.0
        static let thumbnailHeight = 80.0
        static let accessorySize = 44.0
        static let radius = 24.0
    }
}
