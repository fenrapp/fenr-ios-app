public struct DashboardCardSettingsViewState: Equatable, Sendable {
    public let fixedCards: [DashboardCardFixedRowViewData]
    public let sections: [DashboardCardSectionRowViewData]

    public init(
        fixedCards: [DashboardCardFixedRowViewData] = [],
        sections: [DashboardCardSectionRowViewData] = []
    ) {
        self.fixedCards = fixedCards
        self.sections = sections
    }

    public func section(id: String) -> DashboardCardSectionRowViewData? {
        sections.first(where: { $0.id == id })
    }
}
