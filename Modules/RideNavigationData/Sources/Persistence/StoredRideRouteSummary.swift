import Foundation
import RideNavigationDomain

struct StoredRideRouteSummary: Codable, Sendable {
    struct FileVersion: Codable, Equatable, Sendable {
        let size: UInt64
        let modifiedAt: Date
        let createdAt: Date
        let fileNumber: UInt64

        init?(attributes: [FileAttributeKey: Any]) {
            guard let size = attributes[.size] as? NSNumber,
                  let modifiedAt = attributes[.modificationDate] as? Date,
                  let createdAt = attributes[.creationDate] as? Date,
                  let fileNumber = attributes[.systemFileNumber] as? NSNumber else { return nil }
            self.size = size.uint64Value
            self.modifiedAt = modifiedAt
            self.createdAt = createdAt
            self.fileNumber = fileNumber.uint64Value
        }
    }

    let version: Int
    let file: FileVersion
    let summary: RideRouteSummary

    init(file: FileVersion, summary: RideRouteSummary) {
        version = 1
        self.file = file
        self.summary = summary
    }

    func matches(id: UUID, file: FileVersion) -> Bool {
        version == 1 && self.file == file && summary.id == id
            && summary.distanceMeters.isFinite && summary.distanceMeters >= 0
    }
}
