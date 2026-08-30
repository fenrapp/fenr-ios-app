import DesignSystem
import SwiftUI
import UIKit

struct RideNavigationHomePanel: View {
    let state: RideNavigationViewState
    let onClose: () -> Void
    let onImport: () -> Void
    let onRecord: () -> Void
    let onSearchQueryChanged: (String) -> Void
    let onSearch: () -> Void
    let onSelectSearchResult: (UUID) -> Void
    let onOpenRoute: (UUID) -> Void
    let onShareRoute: (UUID) -> Void
    let onDeleteRoute: (UUID) -> Void
    @State private var query = ""
    @State private var keyboardFrame: CGRect?
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let safeFrame = rideNavigationSafeContentFrame(in: proxy)

            ZStack {
                homeCards
                    .frame(width: safeFrame.width, height: safeFrame.height)
                    .position(x: safeFrame.midX, y: safeFrame.midY)

                if isSearchFieldFocused, let keyboardFrame {
                    Button("Done") { isSearchFieldFocused = false }
                        .buttonStyle(.plain)
                        .frame(
                            width: Constants.keyboardDismissButtonWidth,
                            height: Constants.keyboardDismissButtonHeight
                        )
                        .rideNavigationGlassSurface(cornerRadius: Constants.keyboardDismissButtonRadius)
                        .position(
                            rideNavigationKeyboardDismissButtonPosition(
                                in: proxy,
                                keyboardFrame: keyboardFrame,
                                buttonSize: CGSize(
                                    width: Constants.keyboardDismissButtonWidth,
                                    height: Constants.keyboardDismissButtonHeight
                                )
                            )
                        )
                        .transition(.opacity.combined(with: .scale(scale: Constants.doneTransitionScale)))
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.smooth(duration: Constants.doneTransitionDuration), value: isSearchFieldFocused)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) {
            keyboardFrame = $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardFrame = nil
        }
    }

    private var homeCards: some View {
        HStack(alignment: .top, spacing: DesignSpace.medium) {
            panel

            if showsSavedRoutesPanel {
                RideNavigationSavedRoutesPanel(
                    routes: state.savedRoutes,
                    errorText: state.errorText,
                    onOpenRoute: onOpenRoute,
                    onShareRoute: onShareRoute,
                    onDeleteRoute: onDeleteRoute
                )
                .frame(height: homePanelHeight)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(.snappy(duration: Constants.searchTransitionDuration), value: showsSavedRoutesPanel)
    }

    private var panel: some View {
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
                if let errorText = state.errorText, state.savedRoutes.isEmpty {
                    errorBanner(errorText)
                }
            }
        }
        .padding(isSearchMode ? DesignSpace.small : DesignSpace.medium)
        .frame(
            width: isSearchMode ? Constants.searchPanelWidth : Constants.panelWidth,
            height: isSearchMode ? nil : homePanelHeight,
            alignment: .top
        )
        .frame(maxHeight: isSearchMode ? .infinity : nil, alignment: .top)
        .background(
            Color.black.opacity(Constants.interactionShieldOpacity),
            in: RoundedRectangle(cornerRadius: Constants.panelRadius, style: .continuous)
        )
        .rideNavigationGlassSurface(cornerRadius: Constants.panelRadius)
        .contentShape(RoundedRectangle(cornerRadius: Constants.panelRadius, style: .continuous))
        .onTapGesture {}
        .onAppear { query = state.searchQuery }
        .animation(.snappy(duration: Constants.searchTransitionDuration), value: isSearchMode)
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

    private var isSearchMode: Bool {
        isSearchFieldFocused || !query.isEmpty || state.isSearching || !state.searchResults.isEmpty
    }

    private var showsSavedRoutesPanel: Bool {
        !isSearchMode && !state.savedRoutes.isEmpty
    }

    private var savedRoutesPanelHeight: CGFloat {
        let rowsHeight = CGFloat(state.savedRoutes.count) * Constants.savedRouteRowHeight
        return min(
            Constants.savedRoutesMaximumHeight,
            max(Constants.savedRoutesMinimumHeight, Constants.savedRoutesHeaderHeight + rowsHeight)
        )
    }

    private var homePanelHeight: CGFloat {
        max(Constants.planningPanelHeight, savedRoutesPanelHeight)
    }

    private func errorBanner(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(DesignColor.critical)
            .padding(DesignSpace.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                DesignColor.critical.opacity(Constants.errorBackgroundOpacity),
                in: RoundedRectangle(cornerRadius: DesignRadius.medium)
            )
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
        static let searchPanelWidth: CGFloat = 480
        static let planningPanelHeight: CGFloat = 260
        static let savedRoutesMinimumHeight: CGFloat = 150
        static let savedRoutesMaximumHeight: CGFloat = 330
        static let savedRoutesHeaderHeight: CGFloat = 84
        static let savedRouteRowHeight: CGFloat = 64
        static let panelRadius: CGFloat = 24
        static let closeButtonSize: CGFloat = 36
        static let searchHeight: CGFloat = 44
        static let searchBackButtonSize: CGFloat = 44
        static let searchTransitionDuration = 0.28
        static let keyboardDismissButtonWidth: CGFloat = 76
        static let keyboardDismissButtonHeight: CGFloat = 44
        static let keyboardDismissButtonRadius: CGFloat = 22
        static let doneTransitionScale = 0.96
        static let doneTransitionDuration = 0.2
        static let interactionShieldOpacity = 0.001
        static let errorBackgroundOpacity = 0.12
    }
}

private func rideNavigationKeyboardDismissButtonPosition(
    in proxy: GeometryProxy,
    keyboardFrame: CGRect,
    buttonSize: CGSize
) -> CGPoint {
    let viewFrame = proxy.frame(in: .global)
    return CGPoint(
        x: keyboardFrame.maxX - viewFrame.minX - DesignSpace.medium - buttonSize.width / 2,
        y: keyboardFrame.minY - viewFrame.minY - DesignSpace.medium - buttonSize.height / 2
    )
}

private func rideNavigationSafeContentFrame(in proxy: GeometryProxy) -> CGRect {
    let insets = proxy.safeAreaInsets
    let margin = DesignSpace.medium
    return CGRect(
        x: insets.leading + margin,
        y: insets.top + margin,
        width: max(.zero, proxy.size.width - insets.leading - insets.trailing - margin * 2),
        height: max(.zero, proxy.size.height - insets.top - insets.bottom - margin * 2)
    )
}
