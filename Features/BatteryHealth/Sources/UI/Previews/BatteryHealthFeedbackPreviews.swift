import SwiftUI

#Preview("Battery health feedback") {
    List {
        BatteryHealthBannerView(banner: .init(
            kind: .fault,
            title: "Fault reported",
            message: "The vehicle reports an active fault.",
            emphasis: .critical
        ))
        BatteryHealthBannerView(banner: .init(
            kind: .stale,
            title: "Data is stale",
            message: "Waiting for a fresh battery sample.",
            emphasis: .warning
        ))
        BatteryHealthBannerView(banner: .init(
            kind: .monitoring,
            title: "Monitoring unavailable",
            message: "Reconnect the bike to continue monitoring.",
            emphasis: .warning
        ))
    }
}

#Preview("Battery health feedback - large text") {
    List {
        BatteryHealthBannerView(banner: .init(
            kind: .write,
            title: "Charge setting failed",
            message: "The bike did not confirm the requested charge setting.",
            emphasis: .critical
        ))
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
