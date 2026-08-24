import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct BikeLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        let configuration = ActivityConfiguration(for: BikeLiveActivityAttributes.self) { context in
            BikeLiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            BikeLiveActivityDynamicIsland(context: context).body
        }

        if #available(iOSApplicationExtension 18.0, *) {
            return configuration.supplementalActivityFamilies([.small, .medium])
        } else {
            return configuration
        }
    }
}
