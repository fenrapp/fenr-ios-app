import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct ChargingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        let configuration = ActivityConfiguration(for: ChargingLiveActivityAttributes.self) { context in
            ChargingLiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            ChargingLiveActivityDynamicIsland(context: context).body
        }

        if #available(iOSApplicationExtension 18.0, *) {
            return configuration.supplementalActivityFamilies([.small, .medium])
        } else {
            return configuration
        }
    }
}
