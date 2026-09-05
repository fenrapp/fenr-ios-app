import Foundation

public enum DashboardCardSectionID: String, Codable, CaseIterable, Hashable, Sendable {
    case bikeLock
    case navigation
    case currentTrip
    case efficiency
    case range
    case systemHealth
    case rideDynamics
    case settings

    public static let defaultOrder: [Self] = allCases

    public var defaultPageOrder: [DashboardCardPageID] {
        switch self {
        case .bikeLock: []
        case .navigation, .settings: []
        case .currentTrip: [.currentTrip, .rideStatistics]
        case .efficiency: [.efficiencyLive, .efficiencyTrend]
        case .range: [.range, .batteryTrip]
        case .systemHealth: [.systemHealth, .batteryCells, .thermal]
        case .rideDynamics: [.lean, .pitch, .altitude, .course]
        }
    }
}

public enum DashboardCardPageID: String, Codable, CaseIterable, Hashable, Sendable {
    case currentTrip
    case rideStatistics
    case efficiencyLive
    case efficiencyTrend
    case range
    case batteryTrip
    case systemHealth
    case batteryCells
    case thermal
    case lean
    case pitch
    case altitude
    case course

    public var sectionID: DashboardCardSectionID {
        switch self {
        case .currentTrip, .rideStatistics: .currentTrip
        case .efficiencyLive, .efficiencyTrend: .efficiency
        case .range, .batteryTrip: .range
        case .systemHealth, .batteryCells, .thermal: .systemHealth
        case .lean, .pitch, .course, .altitude: .rideDynamics
        }
    }
}

public struct DashboardCardPageConfiguration: Codable, Equatable, Sendable {
    public let id: DashboardCardPageID
    public var isVisible: Bool

    public init(id: DashboardCardPageID, isVisible: Bool = true) {
        self.id = id
        self.isVisible = isVisible
    }
}

public struct DashboardCardSectionConfiguration: Codable, Equatable, Sendable {
    public let id: DashboardCardSectionID
    public var isVisible: Bool
    public var pages: [DashboardCardPageConfiguration]

    public init(
        id: DashboardCardSectionID,
        isVisible: Bool = true,
        pages: [DashboardCardPageConfiguration]? = nil
    ) {
        self.id = id
        self.isVisible = isVisible
        self.pages = pages ?? id.defaultPageOrder.map { DashboardCardPageConfiguration(id: $0) }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case isVisible
        case pages
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(DashboardCardSectionID.self, forKey: .id)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        pages = try container.decodeIfPresent(
            [LossyDecodable<DashboardCardPageConfiguration>].self,
            forKey: .pages
        )?.compactMap(\.value) ?? []
    }
}

public struct DashboardCardConfiguration: Codable, Equatable, Sendable {
    public private(set) var sections: [DashboardCardSectionConfiguration]

    public init(sections: [DashboardCardSectionConfiguration]? = nil) {
        self.sections = Self.normalize(sections ?? [])
    }

    public func section(id: DashboardCardSectionID) -> DashboardCardSectionConfiguration {
        sections.first(where: { $0.id == id })
            ?? DashboardCardSectionConfiguration(id: id)
    }

    public mutating func setSectionOrder(_ orderedIDs: [DashboardCardSectionID]) {
        let byID = Dictionary(uniqueKeysWithValues: sections.map { ($0.id, $0) })
        sections = Self.completeOrder(orderedIDs, defaults: DashboardCardSectionID.defaultOrder)
            .compactMap { byID[$0] }
    }

    public mutating func setSectionVisibility(_ isVisible: Bool, id: DashboardCardSectionID) {
        guard id != .settings else { return }
        guard let index = sections.firstIndex(where: { $0.id == id }) else { return }
        sections[index].isVisible = isVisible
    }

    public mutating func setPageOrder(
        _ orderedIDs: [DashboardCardPageID],
        sectionID: DashboardCardSectionID
    ) {
        guard let index = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        let byID = Dictionary(uniqueKeysWithValues: sections[index].pages.map { ($0.id, $0) })
        sections[index].pages = Self.completeOrder(orderedIDs, defaults: sectionID.defaultPageOrder)
            .compactMap { byID[$0] }
    }

    @discardableResult
    public mutating func setPageVisibility(
        _ isVisible: Bool,
        id: DashboardCardPageID,
        sectionID: DashboardCardSectionID
    ) -> Bool {
        guard id.sectionID == sectionID,
              let sectionIndex = sections.firstIndex(where: { $0.id == sectionID }),
              let pageIndex = sections[sectionIndex].pages.firstIndex(where: { $0.id == id }) else {
            return false
        }
        if !isVisible {
            let visiblePageCount = sections[sectionIndex].pages.filter(\.isVisible).count
            guard visiblePageCount > 1 else { return false }
        }
        sections[sectionIndex].pages[pageIndex].isVisible = isVisible
        return true
    }

    private enum CodingKeys: String, CodingKey {
        case sections
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try container.decodeIfPresent(
            [LossyDecodable<DashboardCardSectionConfiguration>].self,
            forKey: .sections
        )?.compactMap(\.value) ?? []
        sections = Self.normalize(decoded)
    }

    private static func normalize(
        _ sections: [DashboardCardSectionConfiguration]
    ) -> [DashboardCardSectionConfiguration] {
        var seenSections: Set<DashboardCardSectionID> = []
        let knownSections = sections.filter { seenSections.insert($0.id).inserted }
        let byID = Dictionary(uniqueKeysWithValues: knownSections.map { ($0.id, $0) })
        var savedOrder = knownSections.map(\.id)
        if !savedOrder.contains(.navigation) {
            savedOrder.insert(.navigation, at: .zero)
        }
        if !savedOrder.contains(.bikeLock) {
            savedOrder.insert(.bikeLock, at: .zero)
        }
        let orderedIDs = completeOrder(savedOrder, defaults: DashboardCardSectionID.defaultOrder)

        return orderedIDs.map { sectionID in
            let saved = byID[sectionID] ?? DashboardCardSectionConfiguration(id: sectionID)
            var seenPages: Set<DashboardCardPageID> = []
            let knownPages = saved.pages.filter {
                $0.id.sectionID == sectionID && seenPages.insert($0.id).inserted
            }
            let pagesByID = Dictionary(uniqueKeysWithValues: knownPages.map { ($0.id, $0) })
            var savedPageOrder = knownPages.map(\.id)
            if sectionID == .rideDynamics,
               !savedPageOrder.contains(.altitude),
               let compassIndex = savedPageOrder.firstIndex(of: .course) {
                savedPageOrder.insert(.altitude, at: compassIndex)
            }
            let pageIDs = completeOrder(savedPageOrder, defaults: sectionID.defaultPageOrder)
            var pages = pageIDs.map { pagesByID[$0] ?? DashboardCardPageConfiguration(id: $0) }
            if !pages.contains(where: \.isVisible), !pages.isEmpty {
                pages[0].isVisible = true
            }
            return DashboardCardSectionConfiguration(
                id: sectionID,
                isVisible: sectionID == .settings || saved.isVisible,
                pages: pages
            )
        }
    }

    private static func completeOrder<ID: Hashable>(_ values: [ID], defaults: [ID]) -> [ID] {
        var seen: Set<ID> = []
        return (values + defaults).filter { seen.insert($0).inserted && defaults.contains($0) }
    }
}

private struct LossyDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}
