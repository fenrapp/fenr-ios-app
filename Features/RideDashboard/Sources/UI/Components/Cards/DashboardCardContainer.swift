import SwiftUI

struct DashboardCardContainer<CardID: Hashable, Content: View>: View {
    let activeCard: CardID
    let reduceMotion: Bool
    private let content: Content

    init(
        activeCard: CardID,
        reduceMotion: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.activeCard = activeCard
        self.reduceMotion = reduceMotion
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .id(activeCard)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: transitionDuration),
            value: activeCard
        )
    }

    private var transitionDuration: Double { 0.22 }
}
