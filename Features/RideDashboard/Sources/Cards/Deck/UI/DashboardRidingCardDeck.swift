import DesignSystem
import SwiftUI

struct DashboardRidingCardDeck<Content: View>: View {
    let cards: [RidingDashboardCard]
    @Binding var selection: RidingDashboardCard
    let reduceMotion: Bool
    private let content: (RidingDashboardCard) -> Content

    @State private var showsIndicator = false
    @State private var indicatorVisibilityToken = 0

    init(
        cards: [RidingDashboardCard],
        selection: Binding<RidingDashboardCard>,
        reduceMotion: Bool,
        @ViewBuilder content: @escaping (RidingDashboardCard) -> Content
    ) {
        self.cards = cards
        _selection = selection
        self.reduceMotion = reduceMotion
        self.content = content
    }

    @ViewBuilder var body: some View {
        if cards.count == 1, let card = cards.first {
            content(card)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            pagingContent
        }
    }

    private var pagingContent: some View {
        DashboardPager(
            pages: cards,
            selection: $selection,
            axis: .vertical,
            reduceMotion: reduceMotion,
            accessibilityLabel: rideDashboardLocalized(.rideDashboardCardsAccessibility),
            accessibilityValue: \.accessibilityLabel,
            onInteractionChanged: { isInteracting in
                if isInteracting {
                    revealIndicator()
                }
            },
            content: content
        )
        .accessibilityIdentifier("dashboard.cards")
        .overlay(alignment: .trailing) {
            if showsIndicator {
                DashboardPageIndicator(
                    pages: cards,
                    selection: selection,
                    axis: .vertical,
                    activeColor: DesignColor.primaryText
                )
                .offset(x: DashboardRidingCardDeckConstants.indicatorHorizontalOffset)
                .transition(.opacity)
            }
        }
        .onAppear {
            revealIndicator()
        }
        .onChange(of: selection) { revealIndicator() }
        .task(id: indicatorVisibilityToken) {
            guard indicatorVisibilityToken > .zero else { return }
            do {
                try await Task.sleep(for: DashboardRidingCardDeckConstants.indicatorVisibilityDuration)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: DashboardRidingCardDeckConstants.indicatorFadeDuration)) {
                showsIndicator = false
            }
        }
    }

    private func revealIndicator() {
        indicatorVisibilityToken += 1
        withAnimation(.easeIn(duration: DashboardRidingCardDeckConstants.indicatorFadeDuration)) {
            showsIndicator = true
        }
    }
}

private enum DashboardRidingCardDeckConstants {
    static let indicatorHorizontalOffset: CGFloat = 13
    static let indicatorVisibilityDuration = Duration.seconds(1)
    static let indicatorFadeDuration = 0.18
}
