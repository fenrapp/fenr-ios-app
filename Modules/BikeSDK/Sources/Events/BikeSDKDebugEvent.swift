import Foundation

public struct BikeSDKDebugEvent: Equatable, Sendable {
    public let title: String
    public let detail: String
    public let date: Date

    public init(title: String, detail: String, date: Date = Date()) {
        self.title = title
        self.detail = detail
        self.date = date
    }
}
