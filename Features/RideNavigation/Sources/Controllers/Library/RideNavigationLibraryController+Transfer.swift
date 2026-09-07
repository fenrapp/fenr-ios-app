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
        guard let route = snapshot.savedRoutes.first(where: { $0.id == id }) else { return }
        do {
            snapshot.shareRequest = try exportRequest(for: route)
            snapshot.errorMessage = nil
        } catch {
            snapshot.errorMessage = String(localized: .rideNavigationGPXCreateError)
        }
        publish()
    }

    func clearExportRequest() {
        snapshot.exportRequest = nil
        publish()
    }

    func clearShareRequest() {
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
