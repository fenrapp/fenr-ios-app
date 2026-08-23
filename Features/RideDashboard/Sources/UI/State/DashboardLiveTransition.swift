import SwiftUI

enum DashboardLiveTransition {
    static func transition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: RideDashboardLayout.Constants.liveTransitionScale))
    }
}
