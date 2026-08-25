public struct AppSettingsSelectionViewState: Equatable, Sendable {
    public let selectedID: String
    public let options: [AppSettingsOptionViewData]

    public init(selectedID: String, options: [AppSettingsOptionViewData]) {
        self.selectedID = selectedID
        self.options = options
    }
}
