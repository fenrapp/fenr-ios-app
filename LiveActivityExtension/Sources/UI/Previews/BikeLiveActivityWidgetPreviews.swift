import ActivityKit
import SwiftUI
import WidgetKit

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

#Preview("Dynamic Island expanded", as: .dynamicIsland(.expanded), using: BikeLiveActivityPreviewData.attributes) {
    BikeLiveActivityWidget()
} contentStates: {
    BikeLiveActivityPreviewData.charging
    BikeLiveActivityPreviewData.riding
    BikeLiveActivityPreviewData.fault
    BikeLiveActivityPreviewData.connectionLost
}

#Preview("Dynamic Island compact", as: .dynamicIsland(.compact), using: BikeLiveActivityPreviewData.attributes) {
    BikeLiveActivityWidget()
} contentStates: {
    BikeLiveActivityPreviewData.charging
    BikeLiveActivityPreviewData.riding
    BikeLiveActivityPreviewData.fault
    BikeLiveActivityPreviewData.complete
}

#Preview("Dynamic Island minimal", as: .dynamicIsland(.minimal), using: BikeLiveActivityPreviewData.attributes) {
    BikeLiveActivityWidget()
} contentStates: {
    BikeLiveActivityPreviewData.charging
    BikeLiveActivityPreviewData.ridingLowBattery
    BikeLiveActivityPreviewData.connectionLost
}

#Preview("Lock Screen long content", as: .content, using: BikeLiveActivityPreviewData.attributes) {
    BikeLiveActivityWidget()
} contentStates: {
    BikeLiveActivityPreviewData.longChargingContent
}
