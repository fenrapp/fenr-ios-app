import Foundation

public struct BLETraceExportViewData: Identifiable, Sendable {
    public let id: UUID
    public let fileURL: URL

    public init(id: UUID, fileURL: URL) {
        self.id = id
        self.fileURL = fileURL
    }
}
