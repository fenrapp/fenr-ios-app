import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationLibraryController {
    func importGPX(from url: URL) throws -> [RideRoute] {
        let gainedAccess = url.startAccessingSecurityScopedResource()
        defer { if gainedAccess { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try routeLibrary.importRoutes(
            from: data,
            fallbackName: url.deletingPathExtension().lastPathComponent
        )
    }

    func exportRoute(_ route: RideRoute) {
        do {
            snapshot.exportRequest = try exportRequest(for: route)
        } catch {
            snapshot.errorMessage = String(localized: .rideNavigationGPXCreateError)
        }
        publish()
    }

    func shareSavedRoute(id: UUID) {
        guard let requested = snapshot.savedRoutes.first(where: { $0.id == id }) else { return }
        cancelShare()
        sharingRouteID = id
        let generation = shareGeneration
        let lifecycle = lifecycleGeneration
        let context = contextGeneration
        shareTask = Task { [weak self, routeLibrary] in
            defer { self?.completeShare(generation: generation) }
            do {
                guard let route = try await routeLibrary.loadRoute(id: id) else {
                    throw CocoaError(.fileReadNoSuchFile)
                }
                guard !Task.isCancelled, let self, isStarted, shareGeneration == generation,
                      lifecycleGeneration == lifecycle, contextGeneration == context,
                      snapshot.savedRoutes.first(where: { $0.id == id }) == requested else { return }
                snapshot.shareRequest = try exportRequest(for: route)
                snapshot.errorMessage = nil
                publish()
            } catch {
                guard !Task.isCancelled, let self, isStarted, shareGeneration == generation,
                      lifecycleGeneration == lifecycle, contextGeneration == context,
                      snapshot.savedRoutes.first(where: { $0.id == id }) == requested else { return }
                snapshot.errorMessage = String(localized: .rideNavigationGPXCreateError)
                publish()
            }
        }
    }

    private func completeShare(generation: UInt) {
        guard shareGeneration == generation else { return }
        shareTask = nil
        sharingRouteID = nil
    }

    func cancelShare() {
        shareGeneration &+= 1
        shareTask?.cancel()
        shareTask = nil
        sharingRouteID = nil
    }

    func clearExportRequest() {
        snapshot.exportRequest = nil
        publish()
    }

    func clearShareRequest() {
        cancelShare()
        snapshot.shareRequest = nil
        publish()
    }

    private func exportRequest(for route: RideRoute) throws -> GPXExportRequest {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = route.name.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let filename = String(sanitized).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return GPXExportRequest(
            filename: (filename.isEmpty ? String(localized: .rideNavigationDefaultExportName) : filename) + ".gpx",
            data: try routeLibrary.export(route)
        )
    }
}
