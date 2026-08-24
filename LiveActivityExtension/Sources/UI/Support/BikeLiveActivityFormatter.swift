enum BikeLiveActivityFormatter {
    static func batteryText(_ percent: Int?) -> String {
        percent.map { "\($0)%" } ?? "--%"
    }

    static func modeText(_ modeIndex: Int?) -> String {
        modeIndex.map { "M\($0)" } ?? "--"
    }

    static func shortIdentifier(_ identifier: String) -> String {
        guard identifier.count > Constants.shortIdentifierMaximumLength else {
            return identifier
        }
        return String(identifier.suffix(Constants.identifierSuffixLength))
    }

    private enum Constants {
        static let identifierSuffixLength = 6
        static let shortIdentifierMaximumLength = 8
    }
}
