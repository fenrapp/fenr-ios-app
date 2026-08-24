enum BikeLiveActivityText {
    static let current = "Current"
    static let mode = "Mode"
    static let power = "Power"
    static let ready = "Ready"
    static let singleLineLimit = 1
    static let speed = "Speed"
    static let temperature = "Temp"

    static func remaining(_ text: String) -> String {
        "\(text) remaining"
    }

    static func target(_ percent: Int) -> String {
        "Target \(percent)%"
    }
}
