import Foundation

public struct AppSettingsOptionViewData: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: LocalizedStringResource

    public init(id: String, title: LocalizedStringResource) {
        self.id = id
        self.title = title
    }
}
