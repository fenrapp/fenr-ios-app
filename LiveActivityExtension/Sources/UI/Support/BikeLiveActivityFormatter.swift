enum BikeLiveActivityFormatter {
    static func batteryText(_ percent: Int?) -> String {
        percent.map { "\($0)%" } ?? "--%"
    }

    static func modeText(_ modeIndex: Int?) -> String {
        modeIndex.map { "M\($0)" } ?? "--"
    }
}
