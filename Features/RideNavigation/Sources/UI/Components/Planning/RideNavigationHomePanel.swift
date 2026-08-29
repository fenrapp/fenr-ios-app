import DesignSystem
import SwiftUI

struct RideNavigationHomePanel: View {
    let state: RideNavigationViewState
    let onClose: () -> Void
    let onImport: () -> Void
    let onRecord: () -> Void
    let onSearchQueryChanged: (String) -> Void
    let onSearch: () -> Void
    let onSelectSearchResult: (UUID) -> Void
    let onOpenRoute: (UUID) -> Void
    @State private var query = ""
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isSearchMode ? DesignSpace.extraSmall : DesignSpace.medium) {
            if !isSearchMode {
                header
            }
            searchSection
            if isSearchMode {
                RideNavigationSearchResultsView(
                    query: query,
                    results: state.searchResults,
                    isSearching: state.isSearching,
                    errorText: state.errorText,
                    onSelect: selectSearchResult
                )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                rideActions
                savedRoutesSection
            }
        }
        .padding(isSearchMode ? DesignSpace.small : DesignSpace.medium)
        .frame(width: Constants.panelWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            Color.black.opacity(Constants.interactionShieldOpacity),
            in: RoundedRectangle(cornerRadius: Constants.panelRadius, style: .continuous)
        )
        .rideNavigationGlassSurface(cornerRadius: Constants.panelRadius)
        .contentShape(RoundedRectangle(cornerRadius: Constants.panelRadius, style: .continuous))
        .onTapGesture {}
        .padding(.horizontal, DesignSpace.small)
        .padding(.bottom, DesignSpace.small)
        .padding(.top, DesignSpace.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { query = state.searchQuery }
        .animation(.snappy(duration: Constants.searchTransitionDuration), value: isSearchMode)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isSearchFieldFocused = false }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignSpace.medium) {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Label("Ride Navigation", systemImage: "location.north.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Plan a ride")
                    .font(.title.weight(.bold))
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: Constants.closeButtonSize, height: Constants.closeButtonSize)
                    .background(DesignColor.controlSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close ride navigation")
        }
    }

    private var searchSection: some View {
        HStack(spacing: DesignSpace.extraSmall) {
            if isSearchMode {
                Button(action: leaveSearch) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: Constants.searchBackButtonSize, height: Constants.searchHeight)
                        .background(DesignColor.controlSurface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to ride planning")
            }
            searchField
        }
    }

    private var searchField: some View {
        HStack(spacing: DesignSpace.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search a destination", text: $query)
                .focused($isSearchFieldFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(false)
                .submitLabel(.search)
                .onSubmit(onSearch)
                .onChange(of: query) { onSearchQueryChanged(query) }
            if state.isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if !query.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, DesignSpace.medium)
        .frame(height: Constants.searchHeight)
        .background(DesignColor.groupedSurface, in: RoundedRectangle(cornerRadius: DesignRadius.medium))
    }

    private var rideActions: some View {
        HStack(spacing: DesignSpace.small) {
            RideNavigationQuickAction(
                title: "Import GPX",
                subtitle: "Open a trail",
                systemImage: "square.and.arrow.down",
                color: DesignColor.accent,
                action: onImport
            )
            RideNavigationQuickAction(
                title: "Record Ride",
                subtitle: "Track as you go",
                systemImage: "record.circle",
                color: DesignColor.critical,
                action: onRecord
            )
        }
    }

    private var savedRoutesSection: some View {
        VStack(alignment: .leading, spacing: DesignSpace.small) {
            HStack {
                Text("Saved Routes")
                    .font(.headline)
                Spacer()
                if !state.savedRoutes.isEmpty {
                    Text(state.savedRoutes.count, format: .number)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if state.savedRoutes.isEmpty {
                VStack(spacing: DesignSpace.extraSmall) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Imported and recorded routes will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSpace.extraSmall)
            } else {
                ScrollView {
                    LazyVStack(spacing: .zero) {
                        ForEach(Array(state.savedRoutes.enumerated()), id: \.element.id) { index, route in
                            Button { onOpenRoute(route.id) } label: {
                                RideNavigationRow(
                                    title: route.title,
                                    detail: route.detail,
                                    image: "point.topleft.down.to.point.bottomright.curvepath"
                                )
                            }
                            .buttonStyle(.plain)
                            if index < state.savedRoutes.count - 1 {
                                Divider().padding(.leading, Constants.rowDividerInset)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var isSearchMode: Bool {
        isSearchFieldFocused || !query.isEmpty || state.isSearching || !state.searchResults.isEmpty
    }

    private func clearSearch() {
        query = ""
        onSearchQueryChanged("")
        isSearchFieldFocused = true
    }

    private func leaveSearch() {
        query = ""
        onSearchQueryChanged("")
        isSearchFieldFocused = false
    }

    private func selectSearchResult(_ id: UUID) {
        isSearchFieldFocused = false
        onSelectSearchResult(id)
    }

    private enum Constants {
        static let panelWidth: CGFloat = 390
        static let panelRadius: CGFloat = 24
        static let closeButtonSize: CGFloat = 36
        static let searchHeight: CGFloat = 44
        static let searchBackButtonSize: CGFloat = 44
        static let rowDividerInset: CGFloat = 52
        static let searchTransitionDuration = 0.28
        static let interactionShieldOpacity = 0.001
    }
}

private struct RideNavigationQuickAction: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DesignSpace.small)
            .frame(maxWidth: .infinity, minHeight: Constants.minimumHeight, alignment: .leading)
            .background(DesignColor.groupedSurface, in: RoundedRectangle(cornerRadius: DesignRadius.medium))
            .contentShape(RoundedRectangle(cornerRadius: DesignRadius.medium))
        }
        .buttonStyle(.plain)
    }

    private enum Constants {
        static let minimumHeight: CGFloat = 82
    }
}

struct RideNavigationRow: View {
    let title: String
    let detail: String
    let image: String

    var body: some View {
        HStack(spacing: DesignSpace.small) {
            Image(systemName: image)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignColor.accent)
                .frame(width: Constants.iconWidth)
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DesignSpace.small)
        .frame(minHeight: Constants.rowHeight)
        .contentShape(Rectangle())
    }

    private enum Constants {
        static let iconWidth: CGFloat = 28
        static let rowHeight: CGFloat = 56
    }
}
