import DesignSystem
import SwiftUI

struct RideNavigationSavedRoutesPanel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let routes: [RideNavigationRouteRow]
    let errorText: String?
    let onOpenRoute: (UUID) -> Void
    let onShareRoute: (UUID) -> Void
    let onDeleteRoute: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.medium) {
            header

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(DesignColor.critical)
            }

            routeList
        }
        .padding(DesignSpace.medium)
        .frame(maxWidth: Constants.panelWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            Color.black.opacity(Constants.interactionShieldOpacity),
            in: RoundedRectangle(cornerRadius: Constants.panelRadius, style: .continuous)
        )
        .rideNavigationGlassSurface(cornerRadius: Constants.panelRadius)
        .contentShape(RoundedRectangle(cornerRadius: Constants.panelRadius, style: .continuous))
        .onTapGesture {}
    }

    private var header: some View {
        HStack(spacing: DesignSpace.small) {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(.rideNavigationSavedRoutes)
                    .font(.title3.weight(.bold))
                Text(.rideNavigationRouteLibrary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(routes.count, format: .number)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(
                    minWidth: Constants.countBadgeSize,
                    minHeight: Constants.countBadgeSize
                )
                .padding(.horizontal, routes.count > Constants.singleDigitMaximum ? DesignSpace.extraExtraSmall : .zero)
                .background(DesignColor.controlSurface, in: Capsule())
                .accessibilityLabel(String(localized: .rideNavigationSavedRouteCount(routeCount: routes.count)))
                .accessibilityIdentifier("rideNavigation.savedRoute.count")
        }
    }

    private var routeList: some View {
        List(routes) { route in
            Button { onOpenRoute(route.id) } label: {
                savedRouteRow(route)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("rideNavigation.savedRoute")
            .listRowInsets(EdgeInsets(top: .zero, leading: .zero, bottom: DesignSpace.extraSmall, trailing: .zero))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button { onShareRoute(route.id) } label: {
                    Label(.rideNavigationShare, systemImage: "square.and.arrow.up")
                }
                .tint(DesignColor.accent)
                .accessibilityIdentifier("rideNavigation.savedRoute.share")
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) { onDeleteRoute(route.id) } label: {
                    Label(.rideNavigationDelete, systemImage: "trash")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .contentMargins(.vertical, .zero, for: .scrollContent)
    }

    private func savedRouteRow(_ route: RideNavigationRouteRow) -> some View {
        HStack(spacing: DesignSpace.small) {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(route.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                Text(route.detail)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DesignSpace.small)
        .frame(minHeight: Constants.rowHeight)
        .background(DesignColor.groupedSurface, in: RoundedRectangle(cornerRadius: DesignRadius.medium))
        .contentShape(RoundedRectangle(cornerRadius: DesignRadius.medium))
    }

    private enum Constants {
        static let panelWidth: CGFloat = 320
        static let panelRadius: CGFloat = 24
        static let countBadgeSize: CGFloat = 28
        static let singleDigitMaximum = 9
        static let rowHeight: CGFloat = 56
        static let interactionShieldOpacity = 0.001
    }
}
