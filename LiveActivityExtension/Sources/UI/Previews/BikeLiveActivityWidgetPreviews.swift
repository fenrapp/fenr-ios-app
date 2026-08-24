import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 17.0, *)
#Preview("Bike Live Activity", as: .content, using: BikeLiveActivityPreviewData.attributes) {
    BikeLiveActivityWidget()
} contentStates: {
    BikeLiveActivityPreviewData.charging
    BikeLiveActivityPreviewData.balancing
    BikeLiveActivityPreviewData.complete
    BikeLiveActivityPreviewData.riding
    BikeLiveActivityPreviewData.ridingLowBattery
    BikeLiveActivityPreviewData.fault
    BikeLiveActivityPreviewData.connectionLost
}

@available(iOSApplicationExtension 17.0, *)
#Preview("Dynamic Island expanded", as: .dynamicIsland(.expanded), using: BikeLiveActivityPreviewData.attributes) {
    BikeLiveActivityWidget()
} contentStates: {
    BikeLiveActivityPreviewData.charging
    BikeLiveActivityPreviewData.riding
    BikeLiveActivityPreviewData.fault
    BikeLiveActivityPreviewData.connectionLost
}

@available(iOSApplicationExtension 17.0, *)
#Preview("Dynamic Island compact", as: .dynamicIsland(.compact), using: BikeLiveActivityPreviewData.attributes) {
    BikeLiveActivityWidget()
} contentStates: {
    BikeLiveActivityPreviewData.charging
    BikeLiveActivityPreviewData.riding
    BikeLiveActivityPreviewData.fault
    BikeLiveActivityPreviewData.complete
}

@available(iOSApplicationExtension 17.0, *)
#Preview("Dynamic Island minimal", as: .dynamicIsland(.minimal), using: BikeLiveActivityPreviewData.attributes) {
    BikeLiveActivityWidget()
} contentStates: {
    BikeLiveActivityPreviewData.charging
    BikeLiveActivityPreviewData.ridingLowBattery
    BikeLiveActivityPreviewData.connectionLost
}
