import SwiftUI

extension View {
    func dashboardPagingButton() -> some View {
        // Cancel the button's press when a drag wins. Ancestor pagers still receive
        // their simultaneous gesture, including horizontal pagers inside the deck.
        highPriorityGesture(DragGesture(minimumDistance: DashboardPagerConstants.minimumDragDistance))
    }
}
