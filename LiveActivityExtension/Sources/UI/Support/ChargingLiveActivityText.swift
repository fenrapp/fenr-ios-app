enum ChargingLiveActivityText {
    static let current = "Current"
    static let power = "Power"
    static let ready = "Ready"
    static let singleLineLimit = 1
    static let temperature = "Temp"

    static func remaining(_ text: String) -> String {
        "\(text) remaining"
    }

    static func target(_ percent: Int) -> String {
        "Target \(percent)%"
    }
}
