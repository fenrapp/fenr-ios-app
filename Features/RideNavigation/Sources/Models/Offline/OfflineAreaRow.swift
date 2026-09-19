import Foundation

public struct OfflineAreaRow: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let thumbnailRevision: Date?
    public struct Layer: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let detail: String
        public let symbol: String
    }

    public let explanation: String
    public let progressText: String
    public let canUpdate: Bool
    public let layerRows: [Layer]
    public let status: String
    public let symbol: String
    public let layers: String
    public let size: String
    public let updated: String
    public let reminder: String?
    public let progress: Double?
    public let canPause: Bool
    public let canResume: Bool
    public let outlines: [[NavigationMapCoordinate]]
}
