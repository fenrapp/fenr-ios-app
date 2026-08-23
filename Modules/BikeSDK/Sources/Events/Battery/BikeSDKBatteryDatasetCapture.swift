import Foundation

public struct BikeSDKBatteryDatasetCapture: Equatable, Sendable {
    public let dataset: BikeSDKBatteryDataset
    public let byteCount: Int
    public let hex: String
    public let date: Date

    public init(dataset: BikeSDKBatteryDataset, byteCount: Int, hex: String, date: Date) {
        self.dataset = dataset
        self.byteCount = byteCount
        self.hex = hex
        self.date = date
    }
}
