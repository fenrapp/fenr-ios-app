import Foundation

public struct BatteryDatasetCapture: Equatable, Sendable, Identifiable {
    public let dataset: BatteryDataset
    public let byteCount: Int
    public let hex: String
    public let date: Date

    public var id: BatteryDataset { dataset }

    public init(dataset: BatteryDataset, byteCount: Int, hex: String, date: Date) {
        self.dataset = dataset
        self.byteCount = byteCount
        self.hex = hex
        self.date = date
    }
}
