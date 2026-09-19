import DesignSystem
import SwiftUI

public struct OfflineMapsLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var areaToDelete: OfflineAreaRow?
    @State private var confirmsDeletion = false
    @State private var selectedArea: OfflineAreaRow?
    @State private var model: OfflineLibraryViewModel
    private let routeID: UUID?
    private let seed: OfflineMapSelectionSeed?
    private let selectionBuilder: (OfflineMapSelectionSeed) -> AnyView
    private let thumbnailFactory: OfflineMapThumbnailFactory
    private let detailBuilder: (UUID) -> AnyView

    public init(
        model: OfflineLibraryViewModel, routeID: UUID?, seed: OfflineMapSelectionSeed?,
        selectionBuilder: @escaping (OfflineMapSelectionSeed) -> AnyView,
        thumbnailFactory: OfflineMapThumbnailFactory,
        detailBuilder: @escaping (UUID) -> AnyView
    ) {
        _model = State(initialValue: model)
        self.routeID = routeID
        self.seed = seed
        self.selectionBuilder = selectionBuilder
        self.detailBuilder = detailBuilder
        self.thumbnailFactory = thumbnailFactory
    }

    public var body: some View {
        NavigationStack {
            List {
                libraryHeader
                    .listRowInsets(Constants.headerInsets)
                if !model.state.areas.isEmpty {
                    Text(.offlineDownloadedAreas)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .listRowInsets(Constants.headerInsets)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    ForEach(model.state.areas) { area in
                        areaRow(area)
                            .listRowInsets(Constants.areaInsets)
                    }
                }
                if let error = model.errorText ?? model.state.error {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.subheadline).foregroundStyle(DesignColor.critical)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(Constants.headerInsets)
                }
                privacyFooter.listRowInsets(Constants.headerInsets)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowSpacing(DesignSpace.extraSmall)
            .environment(\.defaultMinListRowHeight, .zero)
            .background {
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemGroupedBackground), DesignColor.accent.opacity(Constants.tintOpacity)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .navigationTitle(.offlineMapsTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(.offlineDone) { dismiss() } }
            }
            .fullScreenCover(item: $selectedArea) { detailBuilder($0.id) }
            .fullScreenCover(item: $model.selection, content: selectionBuilder)
        }
        .confirmationDialog(.offlineDeleteTitle, isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button(.offlineDelete, role: .destructive) {
                if let areaToDelete { model.delete(areaToDelete.id) }
                areaToDelete = nil
            }
            Button(.offlineCancel, role: .cancel) { areaToDelete = nil }
        } message: { Text(.offlineDeleteMessage) }
        .onAppear { model.start(routeID: routeID, seed: seed) }
        .onDisappear { model.stop() }
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: DesignSpace.large) {
            Text(.offlineLibrarySubtitle).font(.subheadline).foregroundStyle(.secondary)
            OfflineStorageCard(
                used: model.state.used, free: model.state.free, wifiOnly: model.state.wifiOnly,
                onWiFiOnly: model.setWiFiOnly
            )
            Button(action: model.selectArea) {
                Label(.offlineDownloadArea, systemImage: "plus")
                    .font(.body.weight(.semibold)).frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSpace.extraSmall)
            }
            .rideNavigationPrimaryButton()
            .buttonBorderShape(.capsule)
            .disabled(model.state.isLoading)
            if model.state.isLoading { ProgressView().frame(maxWidth: .infinity) }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func areaRow(_ area: OfflineAreaRow) -> some View {
        OfflineLibraryAreaCard(
            area: area, thumbnail: thumbnailFactory.make(area: area), onOpen: { selectedArea = area },
            onPause: { model.pause(area.id) }, onResume: { model.resume(area.id) }
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { areaToDelete = area; confirmsDeletion = true } label: {
                Label(.offlineDeleteAction, systemImage: "trash")
            }
            .disabled(model.busyAreaIDs.contains(area.id))
            .accessibilityIdentifier("offline.area.delete")
            if area.canUpdate {
                Button { model.update(area.id) } label: {
                    Label(.offlineUpdateAction, systemImage: "arrow.clockwise")
                }
                .tint(DesignColor.accent)
                .disabled(model.busyAreaIDs.contains(area.id))
                .accessibilityIdentifier("offline.area.update")
            }
        }
    }

    private var privacyFooter: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: DesignSpace.small) {
                Text(.offlineStorageExplanation)
                Text(.offlinePrivacyNotice)
                if let privacyURL = URL(string: "https://www.mapbox.com/legal/privacy") {
                    Link(destination: privacyURL) { Text(.offlinePrivacyLink) }
                }
            }
            .font(.caption)
            .padding(.top, DesignSpace.extraSmall)
        } label: {
            Label(.offlineAboutMaps, systemImage: "info.circle").font(.caption)
        }
        .foregroundStyle(.secondary)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private enum Constants {
        static let headerInsets = EdgeInsets(
            top: DesignSpace.medium, leading: DesignSpace.large,
            bottom: DesignSpace.medium, trailing: DesignSpace.large
        )
        static let areaInsets = EdgeInsets(
            top: DesignSpace.extraExtraSmall, leading: DesignSpace.large,
            bottom: DesignSpace.extraExtraSmall, trailing: DesignSpace.large
        )
        static let tintOpacity = 0.06
    }
}
