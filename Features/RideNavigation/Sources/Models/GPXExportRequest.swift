import Foundation

public struct GPXExportRequest: Equatable, Identifiable, Sendable {
    public let id = UUID()
    public let filename: String
    public let data: Data

    public init(filename: String, data: Data) {
        self.filename = filename
        self.data = data
    }
}
