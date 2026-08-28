import BikeDomain

enum DashboardGearMapper {
    static func map(
        runState: BikeRunState,
        modeIndex: Int?,
        modeName: String?
    ) -> DashboardGearViewData {
        switch runState {
        case .unknown:
            .init(display: .text("--"), isActive: false, accessibilityLabel: "Gear unavailable")
        case .off:
            .init(display: .text("OFF"), isActive: false, accessibilityLabel: "Gear off")
        case .neutral, .charging:
            .init(display: .text("N"), isActive: true, accessibilityLabel: "Gear neutral")
        case .on:
            powerMode(modeIndex: modeIndex, modeName: modeName)
        case .crawlForward:
            .init(display: .crawlForward, isActive: true, accessibilityLabel: "Crawl forward")
        case .crawlReverse:
            .init(display: .crawlReverse, isActive: true, accessibilityLabel: "Crawl reverse")
        }
    }

    private static func powerMode(modeIndex: Int?, modeName: String?) -> DashboardGearViewData {
        let display = modeName ?? modeIndex.map(String.init) ?? "--"
        return .init(
            display: .text(display),
            isActive: true,
            accessibilityLabel: display == "--" ? "Power mode unavailable" : "Power mode \(display)"
        )
    }
}
