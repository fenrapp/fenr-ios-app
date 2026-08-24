import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 17.0, *)
#Preview("Charging Live Activity", as: .content, using: ChargingLiveActivityPreviewData.attributes) {
    ChargingLiveActivityWidget()
} contentStates: {
    ChargingLiveActivityPreviewData.charging
    ChargingLiveActivityPreviewData.balancing
    ChargingLiveActivityPreviewData.complete
    ChargingLiveActivityPreviewData.connectionLost
}

@available(iOSApplicationExtension 17.0, *)
#Preview("Dynamic Island expanded", as: .dynamicIsland(.expanded), using: ChargingLiveActivityPreviewData.attributes) {
    ChargingLiveActivityWidget()
} contentStates: {
    ChargingLiveActivityPreviewData.charging
    ChargingLiveActivityPreviewData.connectionLost
}

@available(iOSApplicationExtension 17.0, *)
#Preview("Dynamic Island compact", as: .dynamicIsland(.compact), using: ChargingLiveActivityPreviewData.attributes) {
    ChargingLiveActivityWidget()
} contentStates: {
    ChargingLiveActivityPreviewData.charging
    ChargingLiveActivityPreviewData.complete
}

@available(iOSApplicationExtension 17.0, *)
#Preview("Dynamic Island minimal", as: .dynamicIsland(.minimal), using: ChargingLiveActivityPreviewData.attributes) {
    ChargingLiveActivityWidget()
} contentStates: {
    ChargingLiveActivityPreviewData.charging
    ChargingLiveActivityPreviewData.connectionLost
}
